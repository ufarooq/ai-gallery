import Foundation

// General Keys
let KEY_CURRENT_MODEL = "current_model"
let KEY_LAST_TASK = "last_task"

// UI State Keys
let KEY_SHOW_BOTTOM_SHEET_TEXT_INPUT = "show_bottom_sheet_text_input"
let KEY_SHOW_BOTTOM_SHEET_INFO = "show_bottom_sheet_info"
let KEY_SHOW_MODEL_DOWNLOAD_DIALOG = "show_model_download_dialog"
let KEY_SHOW_MODEL_DELETE_DIALOG = "show_model_delete_dialog"
let KEY_SHOW_SETTINGS_DIALOG = "show_settings_dialog"
let KEY_SHOW_BENCHMARK_RUNNING_DIALOG = "show_benchmark_running_dialog"
let KEY_SHOW_BENCHMARK_RESULT_DIALOG = "show_benchmark_result_dialog"
let KEY_SHOW_ALLOWLIST_DIALOG = "show_allowlist_dialog"
let KEY_ALLOWLIST_SEARCH_TEXT = "allowlist_search_text"

// Text Input & Output
let KEY_TEXT_INPUT = "text_input"
let KEY_TEXT_OUTPUT = "text_output"
let KEY_GENERATED_TEXT_OUTPUT = "generated_text_output" // Specific for text generation

// Image Generation
let KEY_IMAGE_RESULTS = "image_results" // Could be an array of image paths/data
let KEY_IMAGE_GENERATION_PROMPT_INPUT = "image_generation_prompt_input"

// Benchmark Related
let KEY_BENCHMARK_LAST_RUN_RESULT_JSON = "benchmark_last_run_result_json"
let KEY_BENCHMARK_LAST_RUN_MODEL_NAME = "benchmark_last_run_model_name"

// Model Configuration related (could be prefixes or part of a larger structure)
// Example: If each model's config is stored separately.
// const val KEY_CONFIG_PREFIX = "config_"

// Default values or other constants
let DEFAULT_TEXT_INPUT = "The movie was great. The acting was convincing and the plot was thrilling."
let DEFAULT_IMAGE_PROMPT = "A photo of an astronaut riding a horse on the moon"

// Add any other constants from the Kotlin `Consts.kt` file.
// For example, if there are specific model names used as keys:
// let MODEL_NAME_TEXT_CLASSIFICATION = "text_classification_mobilebert"
// etc.
