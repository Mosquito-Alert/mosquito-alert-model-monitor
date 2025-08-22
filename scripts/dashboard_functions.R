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
  
  # Read all status files and create a list of data frames
  jobs_list <- map(status_files, function(file) {
    tryCatch({
      data <- fromJSON(file, flatten = TRUE)
      
      # Create a standardized job record as a data frame
      job_df <- data.frame(
        job_name = data$job_name %||% tools::file_path_sans_ext(basename(file)),
        status = data$status %||% "unknown",
        last_updated = data$last_updated %||% as.character(Sys.time()),
        start_time = data$start_time %||% data$last_updated %||% as.character(Sys.time()),
        duration = as.numeric(data$duration %||% 0),
        progress = as.numeric(data$progress %||% 0),
        cpu_usage = as.numeric(data$cpu_usage %||% 0),
        memory_usage = as.numeric(data$memory_usage %||% 0),
        next_scheduled_run = data$next_scheduled_run %||% NA_character_,
        stringsAsFactors = FALSE
      )
      
      # Handle log_entries - keep as character for consistency
      if (!is.null(data$log_entries) && length(data$log_entries) > 0) {
        if (is.list(data$log_entries)) {
          job_df$latest_log <- paste(tail(data$log_entries, 1)[[1]], collapse = " ")
        } else {
          job_df$latest_log <- as.character(data$log_entries)
        }
      } else {
        job_df$latest_log <- NA_character_
      }
      
      # Handle config - extract key fields as separate columns
      if (!is.null(data$config) && length(data$config) > 0) {
        job_df$project_type <- data$config$project_type %||% "Unknown"
        job_df$frequency <- data$config$frequency %||% "Unknown"
        job_df$priority <- data$config$priority %||% "Unknown"
        job_df$data_source <- data$config$data_source %||% "Unknown"
        job_df$collection_scope <- data$config$collection_scope %||% "Unknown"
        job_df$config_summary <- paste(names(data$config), collapse = ", ")
      } else {
        job_df$project_type <- "Unknown"
        job_df$frequency <- "Unknown"
        job_df$priority <- "Unknown"
        job_df$data_source <- "Unknown"
        job_df$collection_scope <- "Unknown"
        job_df$config_summary <- NA_character_
      }
      
      return(job_df)
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
  
  # Combine all data frames
  jobs_df <- bind_rows(jobs_list)
  
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
