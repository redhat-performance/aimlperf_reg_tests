"""
This script trains a TensorFlow neural net model on Fashion MNIST data across multiple worker
nodes. Part of this script is based on https://www.tensorflow.org/tutorials/keras/classification

Written by Courtney Pacheco for Red Hat, Inc. 2020.
"""

from __future__ import print_function
from datetime import datetime
import sys
import tensorflow as tf
from tensorflow import keras

# Allow soft device placement
tf.config.set_soft_device_placement(True)

class FashionMNISTNeuralNet:

    def __init__(self, num_epochs=100, num_neurons=128, batch_size=32):

        # Set multiworker strategy so that we can run across multiple nodes
        self.multiworker_strategy = tf.distribute.experimental.MultiWorkerMirroredStrategy()

        # Set the number of epochs
        self.num_epochs = num_epochs

        # Set the number of "neurons" (nodes) for the neural net model
        self.num_neurons = num_neurons

        # Set number of nodes in the 'softmax' layer
        self.softmax = 10

        # Set batch size
        self.batch_size = batch_size

        # Initialize the dataset
        self.dataset = self.__load_dataset()

        # Preprocess the dataset
        self.__preprocess_dataset()

        # Initialize the model
        self.model = None


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
        fashion_mnist = keras.datasets.fashion_mnist
        (train_images, train_labels), (test_images, test_labels) = fashion_mnist.load_data()

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

        # Grab the training and testing data, then scale
        train_images = self.dataset['train']['data'] / scale_factor
        test_images = self.dataset['test']['data'] / scale_factor

        # Save the preprocessed data back to the dataset
        self.dataset['train']['data'] = train_images
        self.dataset['test']['data'] = test_images


    def train(self):
        """
        Trains the neural network model
        """
        # Use multiple workers
        with self.multiworker_strategy.scope():

            # Define image heights and widths
            image_height, image_width = 28, 28

            # Define model
            self.model = keras.Sequential([
                            keras.layers.Flatten(input_shape=(image_height, image_width)),
                            keras.layers.Dense(self.num_neurons, activation='relu'),
                            keras.layers.Dense(self.softmax)
                        ])

            # Compile model
            self.model.compile(optimizer='adam',
                               loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
                               metrics=['accuracy'])

            # Fit the model
            data = self.dataset['train']['data']
            labels = self.dataset['train']['labels']
            print('Training...')
            start_train = datetime.now()
            self.model.fit(data, labels, epochs=self.num_epochs, batch_size=self.batch_size)
            finish_train = datetime.now()

            # Calculate elapsed time
            elapsed_time_seconds = (finish_train - start_train).total_seconds()

            # Print elapsed time
            print('    Train time (sec):', elapsed_time_seconds)


    def test(self):
        """
        Tests the neural network model
        """
        # Check if we have already trained
        if self.model is None:
            raise AttributeError('Model has not been trained yet. Please train the model first.')

        # Use multiple workers
        with self.multiworker_strategy.scope():

            # Evaluate
            data = self.dataset['test']['data']
            labels = self.dataset['test']['labels']
            print('Testing...')
            start_test = datetime.now()
            test_loss, test_acc = self.model.evaluate(data, labels, verbose=2, batch_size=self.batch_size)
            finish_test = datetime.now()

            # Calculate elapsed time
            elapsed_time_seconds = (finish_test - start_test).total_seconds()
            
            # Print elapsed time
            print('    Test time (sec):', elapsed_time_seconds)

            # Print loss and accuracy
            print('    Loss:', test_loss)
            print('    Accuracy:', test_acc)


def run_mnist(num_epochs, num_neurons, batch_size):
    """
    Runs the fashion MNIST training and classification neural network

    Parameters
    ----------
    num_epochs: int
        Number of epochs to use when training (default: 100)

    num_neurons: int
        Number of neurons (nodes) to use in the first layer (default: 128)

    batch_size: int
        Training batch size (default: 32)
    """

    # Define the neural network
    neural_net = FashionMNISTNeuralNet(num_epochs, num_neurons, batch_size)

    # Train
    neural_net.train()

    # Test
    neural_net.test()


if __name__ == '__main__':

    # Make sure the user passed in all 3 arguments
    if len(sys.argv) < 4:
        raise RuntimeError('Too few arguments provided. Please provide two arguments: (1.) number of epochs, (2.) number of neurons (nodes), and (3.) batch size.')

    if len(sys.argv) > 4:
        raise RuntimeError('Too many arguments provided. Please provide two arguments: (1.) number of epochs, (2.) number of neurons (nodes), and (3.) batch size.')

    # Convert arguments to integers
    num_epochs = int(sys.argv[1])
    num_neurons = int(sys.argv[2])
    batch_size = int(sys.argv[3])

    # Check the values of the arguments, making sure they're not less than 1
    if num_epochs < 1:
        raise ValueError('Number of epochs must be greater than or equal to 1.')

    if num_neurons < 1:
        raise ValueError('Number of neurons must be greater than or equal to 1.')

    if batch_size < 1:
        raise ValueError('Batch size must be greater than or equal to 1.')

    # Run the MNIST classification
    run_mnist(num_epochs, num_neurons, batch_size)
