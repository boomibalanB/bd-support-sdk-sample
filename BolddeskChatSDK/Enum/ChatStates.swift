enum ChatStates: String {
    case open = "1" // The conversation is in the open status category.
    case hold = "2" // The conversation is in the hold status category.
    case closed = "3" // The conversation is closed.
    case deleted = "4" // The conversation is deleted.
    case spam = "5" // The conversation is marked as spam.
    case restored = "6" // The conversation is restored.
    case composing = "7" // A message in the conversation is being composed by a user.
    case thinking = "8" // The AI agent is preparing a response to the conversation.
    case typingStopped = "9" // The user has stopped typing in the conversation.
    case clearChatSession = "11" // Clear the current chat conversation.
    case startMessaging = "12" // The conversation is created.
}
