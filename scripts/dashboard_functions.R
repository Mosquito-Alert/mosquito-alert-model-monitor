# dashboard_functions.R
# Shared functions for the Mosquito Alert Model Monitor dashboard

library(jsonlite)
library(lubridate)
library(dplyr)
library(purrr)

# Function to load job status from JSON files
load_job_status <- function() {
  status_files <- list.files("data/status", pattern = "*.json", full.names = TRUE)
  
  if (length(status_files) == 0) {
    return(data.frame())
  }
  
  # Read all status files
  jobs_list <- map(status_files, function(file) {
    tryCatch({
      data <- fromJSON(file, flatten = TRUE)
      
      # Create a standardized job record
      job_record <- list(
        job_name = data$job_name %||% tools::file_path_sans_ext(basename(file)),
        status = data$status %||% "unknown",
        last_updated = data$last_updated %||% Sys.time(),
        start_time = data$start_time %||% data$last_updated %||% Sys.time(),
        duration = as.numeric(data$duration %||% 0),
        progress = as.numeric(data$progress %||% 0),
        cpu_usage = as.numeric(data$cpu_usage %||% 0),
        memory_usage = as.numeric(data$memory_usage %||% 0),
        next_scheduled_run = data$next_scheduled_run %||% NA_character_
      )
      
      # Handle log_entries as a single string (latest entry)
      if (!is.null(data$log_entries) && length(data$log_entries) > 0) {
        if (is.list(data$log_entries)) {
          job_record$latest_log <- tail(data$log_entries, 1)[[1]]
          job_record$log_entries <- data$log_entries
        } else {
          job_record$latest_log <- as.character(data$log_entries)
          job_record$log_entries <- list(data$log_entries)
        }
      } else {
        job_record$latest_log <- NA_character_
        job_record$log_entries <- list()
      }
      
      # Handle config as both summary string and full object
      if (!is.null(data$config) && length(data$config) > 0) {
        config_summary <- paste(names(data$config), collapse = ", ")
        job_record$config_summary <- config_summary
        job_record$config <- list(data$config)
      } else {
        job_record$config_summary <- NA_character_
        job_record$config <- list()
      }
      
      return(job_record)
    }, error = function(e) {
      warning(paste("Error reading", file, ":", e$message))
      return(NULL)
    })
  })
  
  # Remove NULL entries
  jobs_list <- jobs_list[!map_lgl(jobs_list, is.null)]
  
  if (length(jobs_list) == 0) {
    return(data.frame())
  }
  
  # Convert to data frame
  jobs_df <- do.call(rbind, map(jobs_list, function(x) as.data.frame(x, stringsAsFactors = FALSE)))
  
  return(jobs_df)
}

# Function to determine status color
get_status_color <- function(status) {
  case_when(
    status == "running" ~ "blue",
    status == "completed" ~ "green", 
    status == "failed" ~ "red",
    status == "pending" ~ "orange",
    status == "waiting" ~ "gray",
    status == "unknown" ~ "gray",
    TRUE ~ "gray"
  )
}

# Function to format duration
format_duration <- function(seconds) {
  # Handle vectors properly
  sapply(seconds, function(s) {
    if (is.na(s) || is.null(s)) return("Unknown")
    
    s <- as.numeric(s)
    if (is.na(s)) return("Unknown")
    
    hours <- floor(s / 3600)
    minutes <- floor((s %% 3600) / 60)
    secs <- s %% 60
    
    if (hours > 0) {
      return(sprintf("%02d:%02d:%02d", hours, minutes, secs))
    } else {
      return(sprintf("%02d:%02d", minutes, secs))
    }
  })
}

# Helper function for null coalescing
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) {
    y
  } else {
    x
  }
}
