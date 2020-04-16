"""
This script trains a TensorFlow neural net model on Fashion MNIST data across multiple worker
nodes. Part of this script is based on https://www.tensorflow.org/tutorials/keras/classification

Written by Courtney Pacheco for Red Hat, Inc. 2020.
"""

from __future__ import print_function
from datetime import datetime
import sys
import numpy as np
import tensorflow as tf
from tensorflow import keras

# Allow for memory growth
physical_devices = tf.config.list_physical_devices('GPU')
for device in physical_devices:
    tf.config.experimental.set_memory_growth(device, True)

# Set min/max values of specific vars
EPOCHS_MIN = 1
EPOCHS_MAX = 100
NEURONS_MIN = 10
NEURONS_MAX = 1000
BATCH_SIZE_MIN = 1
BATCH_SIZE_MAX = 100
NUM_WORKERS_MIN = 1
NUM_WORKERS_MAX = 10
MAX_ATTEMPTS = 10
BATCH_SIZE_PER_REPLICA = 64

class FashionMNISTNeuralNet:

    def __init__(self, num_epochs=10):
        self.startup(num_epochs)


    def startup(self, num_epochs):
        """
        Sets/Resets the object

        Inputs
        ------
        num_epochs: int
            Number of epochs to use when training/testing
        """
        # Set multiworker strategy so that we can run across multiple nodes
        self.__setup_multiworker_strategy()

        # Initialize the dataset
        self.__dataset = self.__load_dataset()

        # Preprocess the dataset
        self.__preprocess_dataset()

        # Get the number of images
        self.__num_train_images = len(self.__dataset['train']['labels'])
        self.__num_test_images = len(self.__dataset['test']['labels'])

        # Get image dimensions
        self.__image_height = np.array(self.__dataset['train']['data']).shape[1]
        self.__image_width = np.array(self.__dataset['train']['data']).shape[2]

        # Setup input pipeline
        self.__setup_input_pipeline()

        # Create and distribute
        self.__create_and_distribute_datasets()

        # Set the number of epochs
        self.num_epochs = num_epochs

        # Initialize the model
        self.model = None

    def __setup_multiworker_strategy(self):
        """
        Sets up the mirrored worker strategy
        """
        # Create the strategy
        self.__multiworker_strategy = tf.distribute.experimental.MultiWorkerMirroredStrategy()

        # Print the number of devices
        print ('Number of devices: {}'.format(self.__multiworker_strategy.num_replicas_in_sync))

    
    def __load_dataset(self):
        """
        Loads the fashion MNIST dataset

        Returns
        -------
        dataset: dict
            A dictionary which contains the training data, testing data, training labels, and
            test labels 
        """
        # Load the data
        attempt = 0
        fashion_mnist = keras.datasets.fashion_mnist
        while attempt < MAX_ATTEMPTS:
            try:
                train_images = None
                train_labels = None
                test_images = None
                test_labels = None
                (train_images, train_labels), (test_images, test_labels) = fashion_mnist.load_data()
                if train_images != None and train_labels != None and test_images != None and test_labels != None:
                    break
            except:
                print('Could not load MNIST data. Trying again until we can load it...')

            attempt += 1

        # Pack into a dictionary
        dataset = {'train': {'data': train_images, 'labels': train_labels}, 'test': {'data': test_images, 'labels': test_labels}}

        return dataset


    def __preprocess_dataset(self):
        """
        Preprocesses the fashion MNIST dataset for Neural Networks

        Returns
        -------
        dataset: dictionary
            The original dataset, but preprocessed
        """

        # We need to scale the image data to a [0,1] scale. We have the data in RGB 0-255 format
        scale_factor = 255.0

        # Adjust the training labels so they're 32-bit integers
        train_labels = self.__dataset['train']['labels']
        train_labels = train_labels.astype(np.int32)

        # Do the same with the testing labels
        test_labels = self.__dataset['test']['labels']
        test_labels = test_labels.astype(np.int32)

        # Grab the training and testing data, then scale
        train_images = self.__dataset['train']['data'] / scale_factor
        test_images = self.__dataset['test']['data'] / scale_factor

        # Save the preprocessed data back to the dataset
        self.__dataset['train']['data'] = train_images
        self.__dataset['test']['data'] = test_images
        self.__dataset['train']['labels'] = train_labels
        self.__dataset['test']['labels'] = test_labels


    def __setup_input_pipeline(self):
        """
        Sets up the input pipeline
        """
        # Use default batch size per replica
        batch_size_per_replica = BATCH_SIZE_PER_REPLICA

        # Set global batch size
        self.__global_batch_size = batch_size_per_replica * self.__multiworker_strategy.num_replicas_in_sync


    def __create_and_distribute_datasets(self):
        """
        Creates and distributes the MNIST datasets
        """

        # Extract the training data and labels
        train_images = np.array(self.__dataset['train']['data'])
        train_labels = np.array(self.__dataset['train']['labels'])

        # Extract the testing data and labels
        test_images = np.array(self.__dataset['test']['data'])
        test_labels = np.array(self.__dataset['test']['labels'])

        # Expand dims of 'test_images' and 'train_images'
        train_images = np.expand_dims(train_images,3)
        test_images = np.expand_dims(test_images,3)

        # Create the datasets
        train_dataset = tf.data.Dataset.from_tensor_slices((train_images, train_labels)).shuffle(self.__num_train_images).batch(self.__global_batch_size)
        test_dataset = tf.data.Dataset.from_tensor_slices((test_images, test_labels)).batch(self.__global_batch_size)

        # Distribute
        self.__train_dist_dataset = self.__multiworker_strategy.experimental_distribute_dataset(train_dataset)
        self.__test_dist_dataset = self.__multiworker_strategy.experimental_distribute_dataset(test_dataset)


    def __compute_loss(self, labels, predictions):
        """
        Computes loss
        """
        per_example_loss = self.__loss_object(labels, predictions)
        return tf.nn.compute_average_loss(per_example_loss, global_batch_size=self.__global_batch_size)


    def __train_step(self, inputs):
        """
        Trains the model

        Code based on: https://www.tensorflow.org/tutorials/distribute/custom_training
        """
        images, labels = inputs

        with tf.GradientTape() as tape:
            predictions = self.model(images, training=True)
            loss = self.__compute_loss(labels, predictions)

        gradients = tape.gradient(loss, self.model.trainable_variables)
        self.optimizer.apply_gradients(zip(gradients, self.model.trainable_variables))

        self.__train_accuracy.update_state(labels, predictions)

        return loss 


    def __distributed_train_step(self, dataset_inputs):
        """
        Computes distributed training step

        Code based on: https://www.tensorflow.org/tutorials/distribute/custom_training
        """
        per_replica_losses = self.__multiworker_strategy.experimental_run_v2(self.__train_step, args=(dataset_inputs,))
        return self.__multiworker_strategy.reduce(tf.distribute.ReduceOp.SUM, per_replica_losses, axis=None)


    def __test_step(self, inputs):
        """
        Same as the '__train_step' function, but for testing

        Taken from: https://www.tensorflow.org/tutorials/distribute/custom_training
        """
        images, labels = inputs

        predictions = self.model(images, training=False)
        t_loss = self.__loss_object(labels, predictions)

        self.__test_loss.update_state(t_loss)
        self.__test_accuracy.update_state(labels, predictions)


    def __distributed_test_step(self, dataset_inputs):
        """
        Identical to the '__distributed_train_step' function, but for testing

        Also taken from same source
        """
        return self.__multiworker_strategy.experimental_run_v2(self.__test_step, args=(dataset_inputs,))


    def run(self):
        """
        Trains and tests the neural network model
        """
        # Capture total train and test time
        total_train_time = 0.0
        total_test_time = 0.0

        # Use multiple workers
        with self.__multiworker_strategy.scope():

            # Defining the loss function
            self.__loss_object = tf.keras.losses.SparseCategoricalCrossentropy(
                from_logits=True,
                reduction=tf.keras.losses.Reduction.NONE)

            # Defining metrics to track loss and accuracy
            self.__test_loss = tf.keras.metrics.Mean(name='test_loss')
            self.__train_accuracy = tf.keras.metrics.SparseCategoricalAccuracy(name='train_accuracy')
            self.__test_accuracy = tf.keras.metrics.SparseCategoricalAccuracy(name='test_accuracy')

            # Generate the model
            self.model = tf.keras.Sequential([
                tf.keras.layers.Conv2D(32, 3, activation='relu'),
                tf.keras.layers.MaxPooling2D(),
                tf.keras.layers.Conv2D(64, 3, activation='relu'),
                tf.keras.layers.MaxPooling2D(),
                tf.keras.layers.Flatten(),
                tf.keras.layers.Dense(64, activation='relu'),
                tf.keras.layers.Dense(10)
            ])

            # Set the optimizer
            self.optimizer = tf.keras.optimizers.Adam()

            # Set the checkpoint
            self.checkpoint = tf.train.Checkpoint(optimizer=self.optimizer, model=self.model)

            for epoch in range(self.num_epochs):

                print('Training...')
                ####### Training #######
                start_train = datetime.now() #START
                total_loss = 0.0
                num_batches = 0
                for x in self.__train_dist_dataset:
                    total_loss += self.__distributed_train_step(x)
                    num_batches += 1
                train_loss = total_loss / num_batches
                finish_train = datetime.now() #STOP

                print('Testing...')
                ####### Testing #######
                start_test = datetime.now() #START
                for x in self.__test_dist_dataset:
                    self.__distributed_test_step(x)
                finish_test = datetime.now() #STOP

            # Calculate elapsed times
            elapsed_train_time_seconds = (finish_train - start_train).total_seconds()
            elapsed_test_time_seconds = (finish_test - start_test).total_seconds()

            template = ('Epoch {}, Loss: {}, Accuracy: {}, Test Loss: {}, Test Accuracy: {}, Train time: {}, Test time: {}')
            print (template.format(epoch+1,
                           train_loss,
                           self.__train_accuracy.result()*100,
                           self.__test_loss.result(),
                           self.__test_accuracy.result()*100),
                           elapsed_train_time_seconds,
                           elapsed_test_time_seconds)
            
            total_train_time += elapsed_train_time_seconds
            total_test_time += elapsed_test_time_seconds

        print('-----------------------------\n')
        print('Total train time: %0.2f' % (total_train_time))
        print('Total test time: %0.2f' % (total_test_time))


#####################################################################################

def run_mnist(num_epochs):
    """
    Runs the fashion MNIST training and classification neural network

    Parameters
    ----------
    num_epochs: int
        Number of epochs to use when training (default: 100)
    """

    # Define the neural network
    neural_net = FashionMNISTNeuralNet(num_epochs)

    # Train and test
    neural_net.run()

#####################################################################################


if __name__ == '__main__':

    # Make sure the user passed in a valid argument
    if len(sys.argv) < 2:
        raise RuntimeError('Missing argument for number of epochs.')

    if len(sys.argv) > 2:
        raise RuntimeError('Too many arguments provided. This script only utilizes one argument, the number of epochs.')

    # Convert argument to integers
    num_epochs = int(sys.argv[1])

    # Check the values of the arguments, making sure they're within the acceptable range
    error_msg_template = 'Number of %s must be in the range of [%d, %d]. You entered: %d.'
    errors = []
    if num_epochs < EPOCHS_MIN or num_epochs > EPOCHS_MAX:
        error_msg_template = 'Number of epochs must be in the range of [%d, %d]. You entered: %d.'
        error_msg = error_msg_template % (EPOCHS_MIN, EPOCHS_MAX, num_epochs)
        raise ValueError(err_msg)

    # Run the MNIST classification
    run_mnist(num_epochs)
