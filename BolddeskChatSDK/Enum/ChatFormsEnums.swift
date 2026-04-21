enum ChatFormsModuleEnum: String {
    case workflow = "1"
    case general = "2"
    case ai = "3"
}


enum ChatWorkflowBlockType: String {
    /// Represents an action to retrieve customer details.
    case getCustomerDetails = "3"
    
    /// Represents an action to retrieve picker input details, where the editor type can be configured as Boolean, Buttons, Dropdown, Multi-Select, List, or Card.
    case getPickerInput = "4"
    
    /// Represents an input block for capturing user input. This includes various types of input such as Date, DateTime, Number, Decimal, Regex, Text, and Text Area.
    case getTextInput = "5"
    
    /// Represents a custom message block for sending a custom message.
    case sendTextMessage = "6"
    
    /// Represents a block that sets a conversation field value.
    case setConversationField = "7"
    
    /// Represents an auto-assign block for automatically assigning an agent to the conversation.
    case autoAssignment = "8"
    
    /// Represents a QB (Query Builder) for branching condition.
    case branchOnConversationField = "9"
    
    /// Represents a selection for branching condition. This includes various block subtypes such as buttons, lists, dropdown, and cards.
    case branchOnPickerInput = "10"
    
    /// Represents a block that triggers the execution of another workflow.
    case callAnotherWorkflow = "11"
    
    /// Represents a block that ends the current workflow.
    case endCurrentWorkflow = "12"
    
    /// Represents a block that displays schedule event message with an action button.
    case scheduler = "25"
    
    /// Represents a block that displays a contact form for creating a support ticket.
    case contactForm = "30"
    
    ///Represents a block that displays a file input to upload the files.
    case getFileInput = "32"
}

enum ChatWorkflowBlockSubType: String {
    /// Represents the absence of an editor type.
    case none = "0"
    
    /// Represents a boolean editor type displayed as pre-configured YES/NO buttons.
    case boolean = "1"
    
    /// Represents an editor type that displays buttons.
    case buttons = "2"
    
    /// Represents an editor type for selecting a single item from a list of options.
    case dropdown = "3"
    
    /// Represents an editor type for selecting multiple items from a list of options.
    case multiSelect = "4"
    
    /// Represents a list that contains options with description.
    case list = "5"
    
    /// Represents a Card block used to display options in carousel view.
    case card = "6"
    
    /// Represents an editor type for capturing text input.
    case text = "7"
    
    /// Represents an editor type for capturing multi-line text input.
    case textArea = "8"
    
    /// Represents an editor type for capturing a date value.
    case date = "9"
    
    /// Represents an editor type for capturing both date and time values.
    case dateTime = "10"
    
    /// Represents an editor type for capturing numerical values.
    case number = "11"
    
    /// Represents an editor type for capturing decimal values.
    case decimal = "12"
    
    /// Represents an editor type that uses regular expressions for validation.
    case regex = "13"
    
    /// Represents an editor type where buttons are used to trigger branching logic.
    case buttonsBranch = "14"
    
    /// Represents an editor type where a dropdown is used to trigger branching logic.
    case dropdownBranch = "15"
    
    /// Represents a list that contains options with description.
    case listBranch = "16"
    
    /// Represents a Card block used to display options in carousel view.
    case cardBranch = "17"
    
    /// Represents an editor type for updating the name field of a user.
    case name = "18"
    
    /// Represents an editor type for updating the Email field of a user.
    case email = "19"
    
    /// Represents an editor type for updating the PhoneNumber field of a user.
    case phone = "20"
    
    /// Represents an editor type for linking a user to the current conversation.
    case linkRequester = "21"
    
    /// Represents an editor type that uses URL expressions for validation.
    case url = "22"
}

enum AIResponseButtonEnum: String {
    case thatHelped = "1"
    case talkToPerson = "2"
    case contactUs = "3"
}
