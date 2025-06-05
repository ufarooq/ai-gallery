import Foundation

enum ChatMessageType: String, Codable, Hashable {
    case LOADING_MESSAGE,
         INFO_MESSAGE,
         WARNING_MESSAGE,
         CONFIG_VALUES_CHANGE_MESSAGE,
         TEXT_MESSAGE,
         IMAGE_MESSAGE,
         IMAGE_WITH_HISTORY_MESSAGE,
         CLASSIFICATION_MESSAGE,
         BENCHMARK_RESULT_MESSAGE,
         BENCHMARK_LLM_RESULT_MESSAGE,
         PROMPT_TEMPLATES_MESSAGE
}

enum ChatSide: String, Codable, Hashable {
    case SYSTEM, USER, MODEL
}
