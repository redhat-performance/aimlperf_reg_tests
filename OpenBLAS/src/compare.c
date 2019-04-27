#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <regex.h>

#define BUFFSIZE 4096
#define MAX_ENTRIES 50
#define MAX_FILENAME_LEN 100
#define MAX_DATETIME_LEN 24
#define PRECISION 1e-5
#define DEBUG

typedef struct {
    char datetime[MAX_DATETIME_LEN];
    int gemm_type;
    int num_threads;
    int num_iters;
    int matrix_A_dims[2];
    int matrix_B_dims[2];
    int matrix_C_dims[2];
    double alpha;
    double beta;
    double gflops_approx;
    double avg_execution_time_sec;
    double execution_time_stdev;
} PerformanceEntry;

typedef struct {
    double gflops_approx[MAX_ENTRIES];
    double avg_execution_time_sec[MAX_ENTRIES];
    double execution_time_stdev[MAX_ENTRIES];
    char datetimes[MAX_ENTRIES][MAX_DATETIME_LEN];
    int M;
    int N;
    int K;
    double alpha;
    double beta;
    int num_profiles;
} CommonProfile; 

bool input_is_positive_number(char number[]);
void read_json(char *json_filename, PerformanceEntry *entries, int *num_entries);
int __parse_int(char *buffer);
void __parse_int_array(char *buffer, int *dim1, int *dim2);
double __parse_double(char *buffer);

int main(int argc, char *argv[]){

    char *input_err_str = "Required args: Number of files, followed by the files themselves. e.g., \"2 file1.json file2.json\"";
    if (argc == 1){
        fprintf(stderr, "No args were passed. %s.\n", input_err_str);
        exit(0);
    }
    if (argc == 2){
        fprintf(stderr, "Only 1 arg was passed. %s.\n", input_err_str);
        exit(0);
    }

    // Check that the number of files is a positive number
    bool num_files_is_positive_number = input_is_positive_number(argv[1]);
    if (num_files_is_positive_number == false){
        fprintf(stderr, "The number of files you entered is not a positive integer. You entered: %s\n", argv[1]);
        exit(0);
    }

    // Get the number of files
    char *pEnd;
    int num_files = (int)(strtol(argv[1], &pEnd, 10));
    
    // Check that the user input the proper number of files
    if (argc <= num_files + 1){
        fprintf(stderr, "You entered that there were %d files, but you only passed in %d names.\n", num_files, num_files + 2 - argc);
        exit(0);
    }
    else if (argc > num_files + 2){
        fprintf(stderr, "You entered that there were %d files, but you passed in too many names.\n", num_files);
        exit(0);
    }

    // Parse file names
    char **files = malloc(sizeof(char*) * num_files * MAX_FILENAME_LEN);
    char *filename;
    int i;
    for (i=0; i<num_files; i++){
        filename = argv[i+2];
        if (access(filename, F_OK) != -1){
            files[i] = filename;
        }
        else{
            fprintf(stderr, "%s does not exist.\n", filename);
            free(files);
            exit(0);
        }
    }

    // For a given JSON document, all the entries will be stored in an 'entries' array
    PerformanceEntry entries[MAX_ENTRIES];

    // For all JSON documents, sgemm and dgemm entries will be stored in their own matrix
    PerformanceEntry **sgemm_entries = (PerformanceEntry**)malloc(sizeof(PerformanceEntry*) * num_files);
    PerformanceEntry **dgemm_entries = (PerformanceEntry**)malloc(sizeof(PerformanceEntry*) * num_files);
    for (i=0; i<MAX_ENTRIES; i++){
        sgemm_entries[i] = (PerformanceEntry*)malloc(sizeof(PerformanceEntry) * MAX_ENTRIES);
        dgemm_entries[i] = (PerformanceEntry*)malloc(sizeof(PerformanceEntry) * MAX_ENTRIES);
    }

    // Set up variables
    int num_entries;              //keeps track of the number of entries found in the JSON file
    int j;                        //iterative variable
    int sgemm_count, dgemm_count; //keeps track of how many sgemm and dgemm results we have
    PerformanceEntry entry;       //temporary variable
    int *sgemm_entry_counts = malloc(sizeof(int) * num_files);
    int *dgemm_entry_counts = malloc(sizeof(int) * num_files);

#ifdef DEBUG
    printf("Reading JSON Files\n");
    printf("=======================\n");
#endif

    // Process JSON file(s)
    for (i=0; i<num_files; i++){
#ifdef DEBUG
        printf("Reading file %d of %d\n", i+1, num_files);
#endif

        // Set counts to zero
        sgemm_count = 0;
        dgemm_count = 0;

        // Read the JSON file and capture the entries
        read_json(files[i], entries, &num_entries);

        // For each entry, break it down into sgemm or dgemm
        for (j=0; j<num_entries; j++){
            entry = entries[j];

            if (entry.gemm_type == 1){
                sgemm_entries[i][sgemm_count] = entry;
                sgemm_count++;
            }
            else{
                dgemm_entries[i][dgemm_count] = entry;
                dgemm_count++;
            }
        }

        // Update the number of entry counts for sgemm and dgemm for the current file
        sgemm_entry_counts[i] = sgemm_count;
        dgemm_entry_counts[i] = dgemm_count;

#ifdef DEBUG
        printf("   - # of sgemm entries: %d\n", sgemm_count);
        printf("   - # of dgemm entries: %d\n", dgemm_count);
#endif
    }


    // Prepare to process sgemm and dgemm entries to see if we're looking at the same parameters
    CommonProfile **sgemm_cprofiles = (CommonProfile**)malloc(sizeof(CommonProfile*) * num_files);
    CommonProfile **dgemm_cprofiles = (CommonProfile**)malloc(sizeof(CommonProfile*) * num_files);

    for (i=0; i<MAX_ENTRIES; i++){
        sgemm_cprofiles[i] = (CommonProfile*)malloc(sizeof(CommonProfile) * MAX_ENTRIES);
        dgemm_cprofiles[i] = (CommonProfile*)malloc(sizeof(CommonProfile) * MAX_ENTRIES);
    }

    // Initialize temporary/intermediate variables
    int h, g, profile_idx, M, N, K, existing_M, existing_N, existing_K, existing_idx;
    double alpha, beta, existing_alpha, existing_beta;
    CommonProfile cprofile;
    bool unique_profile;
#ifdef DEBUG
        printf("\nFinding common profiles\n");
        printf("=======================\n");
#endif
    for (i=0; i<num_files; i++){

        profile_idx = 0;
        unique_profile = true;

        // SGEMM
        for (j=0; j<sgemm_entry_counts[i]; j++){
            
            // Get current entry in the current file
            entry = sgemm_entries[i][j];

            // Get dims
            M = entry.matrix_A_dims[0];
            K = entry.matrix_A_dims[1];
            N = entry.matrix_B_dims[1];
            if (entry.matrix_B_dims[0] != K){
                fprintf(stderr, "Error reading JSON file. Matrix dims are invalid. K != K.");
                free(sgemm_entry_counts);
                free(dgemm_entry_counts);
                free(sgemm_entries);
                free(dgemm_entries);
                exit(0);
            }
            else if (entry.matrix_C_dims[0] != M){
                fprintf(stderr, "Error reading JSON file. Matrix dims are invalid. M != M");
                free(sgemm_entry_counts);
                free(dgemm_entry_counts);
                free(sgemm_entries);
                free(dgemm_entries);
                exit(0);
            }

            // Get alpha and beta
            alpha = entry.alpha;
            beta = entry.beta;

            // Check if the current dimension is unique
            for (h=0; h<profile_idx; h++){
                
                // Get existing unique M, N, and K values
                existing_M = sgemm_cprofiles[i][h].M;
                existing_N = sgemm_cprofiles[i][h].N;
                existing_K = sgemm_cprofiles[i][h].K;

                // Get existing alpha and beta values
                existing_alpha = sgemm_cprofiles[i][h].alpha;
                existing_beta = sgemm_cprofiles[i][h].beta;

                // We (possibly) have a unique profile if we have a unique combination of M, N, K, alpha, and beta
                if (M != existing_M || N != existing_N || K != existing_K || alpha != existing_alpha || beta != existing_beta){
                    unique_profile = true;
                }
                else{
                    unique_profile = false;
                    break;
                }
            }

            // If we have a unique profile, let's create one
            if (unique_profile == true){

#ifdef DEBUG
                printf("Creating unique profile #%d under %s\n", profile_idx+1, files[i]);
                printf("    <> Dims:\n");
                printf("        - M: %d\n", M);
                printf("        - N: %d\n", N);
                printf("        - K: %d\n", K);
                printf("    <> Scalar values:\n");
                printf("        - alpha: %0.2f\n", alpha);
                printf("        - beta:  %0.2f\n", beta);
#endif

                // Add data to 'cprofile' temp var
                cprofile.M = M;
                cprofile.N = N;
                cprofile.K = K;
                cprofile.alpha = alpha;
                cprofile.beta = beta;
                cprofile.gflops_approx[0] = entry.gflops_approx;
                cprofile.avg_execution_time_sec[0] = entry.avg_execution_time_sec;
                cprofile.execution_time_stdev[0] = entry.execution_time_stdev;
                cprofile.num_profiles = 1;
                for (g=0; g<MAX_DATETIME_LEN; g++)
                    cprofile.datetimes[0][g] = entry.datetime[g];

                // Add the profile to the unique profiles
                sgemm_cprofiles[i][profile_idx] = cprofile;
                profile_idx++;
            }
            else{
#ifdef DEBUG
                printf("Appending profile #%d with new data\n", h+1);
                printf("   New entry: ");
                for (g=0; g<MAX_DATETIME_LEN; g++)
                    printf("%c", entry.datetime[g]);
                printf("\n");
#endif

                // Update existing cprofile
                existing_idx = sgemm_cprofiles[i][h].num_profiles;
                sgemm_cprofiles[i][h].gflops_approx[existing_idx]          = entry.gflops_approx;
                sgemm_cprofiles[i][h].avg_execution_time_sec[existing_idx] = entry.avg_execution_time_sec;
                sgemm_cprofiles[i][h].execution_time_stdev[existing_idx]   = entry.execution_time_stdev;
                sgemm_cprofiles[i][h].num_profiles += 1;
                for (g=0; g<MAX_DATETIME_LEN; g++)
                    sgemm_cprofiles[i][h].datetimes[existing_idx][g] = entry.datetime[g];
            }
        }
    }

#ifdef DEBUG
    printf("\n");
    printf("List of profiles found\n");
    printf("=======================\n");
    for (i=0; i<num_files; i++){
        printf("%s\n", files[i]);
        h = 0;
        while (sgemm_cprofiles[i][h].M != 0){
            printf("    <> Profile #%d:\n", h+1);
            cprofile = sgemm_cprofiles[i][h];
            printf("        - (M, N, K): (%d,%d,%d)\n", cprofile.M, cprofile.N, cprofile.K);
            printf("        - (alpha, beta): (%0.2f,%0.2f)\n", cprofile.alpha, cprofile.beta);
            printf("        - %d data point(s)\n", cprofile.num_profiles);
            h++;
        }
        printf("\n");
    }
#endif


    // Find max performance for each common profile
    double gflops_approx, max_gflops;
    int max_idx;
    CommonProfile max_cprofile;
    for (i=0; i<num_files; i++){
        max_idx = -1;
        max_gflops = -1;
        gflops_approx = -1;

        // For each file, we want to iterate through each common profile
        h = 0;
        while (sgemm_cprofiles[i][h].M != 0){
            cprofile = sgemm_cprofiles[i][h];

            for (j=0; j<cprofile.num_profiles; j++){
                gflops_approx = cprofile.gflops_approx[j];
                if (gflops_approx > max_gflops){
                    max_gflops = gflops_approx;
                    max_idx = j;
                    max_cprofile = cprofile;
                }
            }
            h++;
        }

        if (max_idx == -1 || max_gflops == -1 || gflops_approx == -1){
            fprintf(stderr, "Date index assertion failed.\n");
            exit(0);
        }

        printf("Max performance for %s occured on ", files[i]);
        for (g=0; g<MAX_DATETIME_LEN; g++){
            printf("%c", max_cprofile.datetimes[max_idx][g]);
        }
        printf(" with %0.2f GFlops\n", max_gflops);
    }

    return 0;
}

bool input_is_positive_number(char number[]){
/* Checks if an input is a positive number, rather than a negative number or a string
 * 
 * SOURCE: https://stackoverflow.com/a/29248688/7093236
 *
 * Inputs
 * ------
 *     char number[]
 *         The "number" to check
 * Returns
 * -------
 *     true/false
 */
    int i = 0;
    if (number[0] == '-')
        return false;

    for (; number[i] != 0; i++){
        if (number[i] > '9' || number[i] < '0')
            return false;
    }
    return true;
};

void read_json(char *json_filename, PerformanceEntry *entries, int *num_entries){
/* Reads a JSON file and parses it, outputting everything to a PerformanceEntry struct
 *
 * Inputs
 * ------
 *     char *json_filename
 *         Name of the JSON file to parse
 *
 *     PerformanceEntry *entries
 *         List of entries for performance results
 *
 *     int num_entries
 *         Number of entries found
 */

    // Define performance entry struct
    PerformanceEntry entry;

    // Keep track of the number of entries
    int performance_entry_count = 0;
    
    // Create buffer
    char buffer[BUFFSIZE] = {'\0'};

    // Open JSON file
    FILE *json_file = fopen(json_filename, "r");

    // Define YYYY MM DD HH:MM:SS regex pattern
    char *yyyy_mm_dd_pattern = "([0-9]{4})\\-(0?[1-9]|1[012])\\-(0?[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|2[0-3]):([0-5]?[0-9]):([0-5][0-9])";

    // Initialize variables for regex.h regex function
    regex_t regex;
    int reti;
    size_t nmatch = 1;
    regmatch_t pmatch[nmatch];

    int len;
    char datetime_result[MAX_DATETIME_LEN];

    int i,j;
    bool parse_inputs, parse_performance_results;
    int dim1, dim2;
    while (fgets(buffer, BUFFSIZE, json_file)){

        // We don't need or want to process brackets
        if (buffer[0] == '{')
            continue;
        if (strstr(buffer, "}") != NULL)
            continue;

        // Compile regex
        reti = regcomp(&regex, yyyy_mm_dd_pattern, REG_EXTENDED);
        if (reti){
            fprintf(stderr, "Could not compile regex\n");
            exit(0);
        }

        // Search for match
        reti = regexec(&regex, buffer, nmatch, pmatch, REG_NOTBOL);

        // If there's no match, then it means we haven't found a datetime string yet
        if (reti == 0){
            for (j=0; j<nmatch; j++){
                len = pmatch[j].rm_eo - pmatch[j].rm_so;
                memcpy(datetime_result, buffer + pmatch[j].rm_so, len);
                datetime_result[len] = 0;

                for (i=0; i<MAX_DATETIME_LEN; i++){
                    entry.datetime[i] = datetime_result[i];
                }
            }
            continue;
        }

        // Check if we're ready to parse inputs or performance results
        if (strstr(buffer, "inputs") != NULL){
            parse_inputs = true;
            parse_performance_results = false;
            performance_entry_count++;
            continue;
        }
        else if (strstr(buffer, "performance_results") != NULL){
            parse_performance_results = true;
            parse_inputs = false;
            continue;
        }
        
        // We're at the stage where we need to parse the inputs
        if (parse_inputs == true){

            if (strstr(buffer, "sgemm") != NULL){
                entry.gemm_type = 1;
            }
            else if (strstr(buffer, "dgemm") != NULL){
                entry.gemm_type = 2;
            }
            else if (strstr(buffer, "iterations") != NULL){
                entry.num_iters = __parse_int(buffer);
            }
            else if (strstr(buffer, "threads") != NULL){
                entry.num_threads = __parse_int(buffer);
            }
            else if (strstr(buffer, "matrix_A") != NULL){
                __parse_int_array(buffer, &dim1, &dim2);
                entry.matrix_A_dims[0] = dim1;
                entry.matrix_A_dims[1] = dim2;
            }
            else if (strstr(buffer, "matrix_B") != NULL){
                __parse_int_array(buffer, &dim1, &dim2);
                entry.matrix_B_dims[0] = dim1;
                entry.matrix_B_dims[1] = dim2;
            }
            else if (strstr(buffer, "matrix_C") != NULL){
                __parse_int_array(buffer, &dim1, &dim2);
                entry.matrix_C_dims[0] = dim1;
                entry.matrix_C_dims[1] = dim2;
            }
            else if (strstr(buffer, "alpha") != NULL){
               entry.alpha = __parse_double(buffer);
            }
            else if (strstr(buffer, "beta") != NULL){
               entry.beta = __parse_double(buffer);
            }
        }
        else if (parse_performance_results == true){
            if (strstr(buffer, "average_execution_time_seconds") != NULL){
                entry.avg_execution_time_sec = __parse_double(buffer);
            }
            else if (strstr(buffer, "standard_deviation_seconds") != NULL){
                entry.execution_time_stdev = __parse_double(buffer);
            }
            else if (strstr(buffer, "average_gflops") != NULL){
                entry.gflops_approx = __parse_double(buffer);
            }
        }

        if (performance_entry_count > 0)
            entries[performance_entry_count - 1] = entry;

        for (j=0; j<BUFFSIZE; j++)
            buffer[j] = '\0';


    }

    // Close JSON file
    fclose(json_file);

    // Save
    *num_entries = performance_entry_count;
}

int __parse_int(char buffer[]){
/* Parses an integer from a JSON file. Do not call this function directly!
 *
 * Inputs
 * ------
 *     char *buffer
 *         String buffer to parse
 *
 * Returns
 * -------
 *     int parsed_integer
 *         Integer that has been parsed
 */
    bool start_parse = false;
    char current_char = '\0';
    int char_as_int;
    int parsed_integer = 0;
    int i;
    for (i=0; i<BUFFSIZE; i++){

        // Get current character in the buffer
        current_char = buffer[i];    

        // We want to start parsing once we reach the ':' char
        if (current_char != ':' && start_parse == false){
            continue;
        }
        else if (current_char == ':'){
            start_parse = true;
            continue;
        }

        if (current_char >= '0' && current_char <= '9'){
            char_as_int = current_char - '0';
            parsed_integer *= 10;
            parsed_integer += char_as_int;
        }
    }
    return parsed_integer;
}

void __parse_int_array(char buffer[], int *dim1, int *dim2){
/* Parses an integer array from a JSON file. Do not call this function directly!
 *
 * Inputs
 * ------
 *     char *buffer
 *         String buffer to parse
 *
 *     int *dims_arr
 *         Array which will hold the dimensions
 */
    bool start_parse = false;
    bool start_dim1 = false;
    bool start_dim2 = false;
    char current_char = '\0';
    int char_as_int;
    int parsed_integer1 = 0;
    int parsed_integer2 = 0;
    int i;
    for (i=0; i<BUFFSIZE; i++){

        // Get current character in the buffer
        current_char = buffer[i];    

        // We want to start parsing once we reach the ':' char
        if (current_char != ':' && start_parse == false)
            continue;
        else if (current_char == ':'){
            start_parse = true;
            continue;
        }

        // If we've reached the bracket char, that means we're at the start of the list
        if (current_char == '['){
            start_dim1 = true;
            continue;
        }

        // If we've reached the comma char, that means we're ready to parse the second dimension
        if (current_char == ','){
            start_dim2 = true;
            start_dim1 = false;
            continue;
        }

        if (current_char == ']')
            break;

        // If we've reached a digit, we're ready to start parsing
        if (current_char != ' ' && current_char != '\0' && current_char != '\n' && current_char != ']'){
            char_as_int = current_char - '0';

            if (start_dim1 == true){
                parsed_integer1 = parsed_integer1 * 10;
                parsed_integer1 += char_as_int;
            }
            else if (start_dim2 == true){
                parsed_integer2 = parsed_integer2 * 10;
                parsed_integer2 += char_as_int;
            }
            else{
                fprintf(stderr, "Unknown error occurred. Exiting now.\n");
                exit(0);
            }
        }
    }

    // Save results
    *dim1 = parsed_integer1;
    *dim2 = parsed_integer2;
}

double __parse_double(char buffer[]){
/* Parses a double
 *
 * Inputs
 * ------
 *     char *buffer
 *         String buffer to parse
 *
 * Returns
 * -------
 *     double parsed_double
 *         Parsed double value
 */
    bool start_parse = false;
    bool start_decimal = false;
    char current_char = '\0';
    int char_as_int;
    double parsed_double = 0;
    double parsed_decimal_part = 0;
    int decimal_count = 0;
    int i;
    for (i=0; i<BUFFSIZE; i++){

        // Get current character in the buffer
        current_char = buffer[i];    

        // We want to start parsing once we reach the ':' char
        if (current_char != ':' && start_parse == false)
            continue;
        else if (current_char == ':'){
            start_parse = true;
            continue;
        }

        if (current_char == '.'){
            start_decimal = true;
            continue;
        }

        if (current_char >= '0' && current_char <= '9'){

            char_as_int = current_char - '0';
            if (start_decimal == false){
                parsed_double *= 10;
                parsed_double += (double)char_as_int;
            }
            else{
                parsed_decimal_part += (double)(char_as_int * pow(10,-decimal_count-1));
                decimal_count++;
            }
        }
    }
    return parsed_double + parsed_decimal_part;
}
