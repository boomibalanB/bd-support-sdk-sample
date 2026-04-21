import SwiftUI
import UIKit
import WebKit

struct ChatMessageView: View {
    @ObservedObject var viewModel: ChatViewModel
    let message: Message
    let onRetryClick: ((String) -> Void)?
    let onFormSubmit: ((FormDetails, String, String, [DropdownItemModel]?, [File]?) -> Void)?
    let onScheduleEvent: ((String) -> Void)?
    let isFormElementDisabled: Bool
    @State private var formErrorMsg: String = ""
    @State private var isFormValid: Bool = true
    @State private var formValue: String = ""
    @State private var formPickerValue: [DropdownItemModel] = []
    @State private var showSchedulerSheet: Bool = false
    @State private var canShowCreateTicketWeb: Bool = false

    
    init(viewModel: ChatViewModel, message: Message, onRetryClick: ((String) -> Void)? = nil, onFormSubmit: ((FormDetails, String, String, [DropdownItemModel]?, [File]?) -> Void)? = nil, onScheduleEvent: ((String) -> Void)? = nil, isFormElementDisabled: Bool = false) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.message = message
        self.onRetryClick = onRetryClick
        self.onFormSubmit = onFormSubmit
        self.onScheduleEvent = onScheduleEvent
        self.isFormElementDisabled = isFormElementDisabled
        // Initialize errorMessage based on formDetails.errorMessage
        let initialErrorMessage = message.formDetails?.errorMessage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        _formErrorMsg = State(initialValue: initialErrorMessage)
        // Initialize isValid based on whether initialErrorMessage is empty
        _isFormValid = State(initialValue: initialErrorMessage.isEmpty)
    }
    
    var body: some View {
        if message.type == .chatStates {
            let msg: String? = message.chatStates == .open ? ResourceManager.localized("conversation_reopened") : message.chatStates == .closed ? ResourceManager.localized("conversation_ended") : nil
            if let msg {
                notificationMsg(content: Text(msg))
            }
        } else if message.type == .assigneeFieldUpdate, let notificationText = message.text {
            notificationMsg(content: HTMLContentView(html: notificationText))
        } else if (message.text?.isEmpty == false) || (message.files?.isEmpty == false) || (message.formDetails != nil) || (message.fieldValueDetails != nil) {
            if message.userType == .agent {
                HStack(alignment: .top, spacing: 10) {
                    if let agentInfo = message.agentInfo {
                        AgentAvatarSection(agentInfo: agentInfo)
                    } else {
                        Circle()
                            .frame(width: 32, height: 32)
                            .foregroundColor(Color.utilityBrand100)
                            .overlay(Text("A").foregroundColor(.white))
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.agentInfo?.displayName ?? "Agent")
                            .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                            .foregroundColor(Color.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        content
                            .lineSpacing(6)
                            .padding(10)
                            .background(Color.bgSecondary)
                            .clipShape(CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12))
                            .overlay(
                                CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12)
                                    .stroke(Color.borderSecondary, lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.trailing, DeviceConfig.isIPad ? 100 : 10)
                .padding(.top, 8)
            } else { // Customer
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Spacer()
                        content
                            .lineSpacing(6)
                            .padding(10)
                            .frame(
                                minWidth: DeviceConfig.isIPad && message.formDetails != nil ? CGFloat(460) : nil,
                                idealWidth: DeviceConfig.isIPad && message.formDetails != nil ? CGFloat(460) : nil,
                                maxWidth: DeviceConfig.isIPad && message.formDetails != nil ? CGFloat(460) : nil,
                                alignment: .trailing
                            )
                            .background([.toSent, .notSent, .uploading].contains( message.deliveryStatus) ? Color.bgBrandSolid.opacity(0.5) : message.isRetracted ? Color.bgSecondary : Color.bgBrandSolid)
                            .clipShape(CustomCorners(topLeft: 12, topRight: 2, bottomLeft: 12, bottomRight: 12))
                    }
                    if message.deliveryStatus == .notSent && message.userType == .customer {
                        HStack(spacing: 4) {
                            Spacer()
                            Text(ResourceManager.localized("could_not_send"))
                                .foregroundColor(Color.textErrorPrimary)
                                .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                            Text("•")
                                .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                            Button(ResourceManager.localized("retry")) {
                                if let retryClickHandler = self.onRetryClick {
                                    retryClickHandler(message.id)
                                }
                            }
                            .foregroundColor(Color.actionColorPrimaryBg)
                            .font(FontFamily.customFont(size: FontSize.xsmall, weight: .semibold))
                        }
                    }
                }
                .padding(.leading, DeviceConfig.isIPad ? 100 : 40)
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            
            // Render AI options outside the chat bubble
            if let formDetails = message.formDetails, !formDetails.isSubmitted {
                if formDetails.mod == .ai, let options = formDetails.options, !options.isEmpty {
                    FormOptionView(options: options, onOptionTap: { option in
                        formPickerValue = [option]
                        if option.id == AIResponseButtonEnum.contactUs.rawValue {
                            canShowCreateTicketWeb = true
                            return
                        }
                        if let onFormSubmit = self.onFormSubmit {
                            onFormSubmit(formDetails, message.id, "", [option], nil)
                        }
                    }, isDisabled: isFormElementDisabled)
                    .padding(.leading, 56)
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .trailing, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                if let textContent = message.text, !textContent.isEmpty, message.fieldValueDetails?.fieldValueType != "file" {
                    if message.isRetracted {
                        HStack(alignment: .top) {
                            AppIcon(icon: .trash, color: .textSecondary)
                            Text(textContent)
                                .font(.system(size: FontSize.medium, weight: .regular))
                                .italic()
                                .foregroundColor(.textSecondary)
                        }
                    } else if message.textFormat == .markdown {
                        Text(.init(textContent))
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                            .foregroundColor(message.userType == .agent ? .textSecondary : .textPrimaryOnBrand)
                    } else if message.textFormat == .html {
                        htmlMessageView(textContent)
                    } else {
                        AutoLinkText(text: textContent, color: message.userType == .agent ? .textSecondary : .textPrimaryOnBrand)
                    }
                } else if message.type == .form, let formDetails = message.formDetails {
                    if !formDetails.description.isEmpty {
                        HStack(spacing: 8){
                            if formDetails.type == .getFileInput,
                               let allowedTypes = formDetails.allowedFileTypes,
                               !allowedTypes.isEmpty {
                                let formats = allowedTypes.joined(separator: ", ")
                                HTMLTooltipView(
                                    html: formDetails.description,
                                    tooltipMessage: "\(ResourceManager.localized("supportedFileFormats")) \(formats)"
                                )
                            } else {
                                HTMLTooltipView(
                                    html: formDetails.description,
                                    tooltipMessage: nil
                                )
                            }
                        }
                    }
                                                    
                    if formDetails.mod == .workflow && formDetails.type == .scheduler, let scheduler = formDetails.scheduler {
                        Button {
                            showSchedulerSheet = true
                        } label: {
                            Text(scheduler.buttonText ?? "")
                        }
                        .buttonStyle(CustomButtonStyle())
                        .padding(.top, 6)
                        .opacity(formDetails.isSubmitted ? 0.7 : 1)
                        .disabled(formDetails.isSubmitted)
                        .sheet(isPresented: $showSchedulerSheet) {
                            SchedulerBottomSheet(
                                url: scheduler.calendlyUrl ?? "",
                                onDismiss: { showSchedulerSheet = false },
                                onEventScheduled: { eventUri in
                                    onScheduleEvent?(eventUri)
                                },
                                forCreateForm: false
                            )
                        }
                    } else if formDetails.mod == .workflow && !formDetails.isSubmitted && formDetails.type != .contactForm {
                        renderFormField(formDetails: formDetails)
                            .padding(.top, 4)
                        HStack(spacing: 12) {
                            if formDetails.type == .getFileInput && (message.files ?? []).isEmpty {
                                AttachmentPickerView(
                                    isEnabled: true,
                                    onFilesPicked: { urls in
                                        viewModel.uploadFiles(urls, forWorkflowFileInput: true, message: message)
                                    },
                                    onImagePicked: { image in
                                        viewModel.uploadFiles(image, forWorkflowFileInput: true, message: message)
                                    }
                                ) {
                                    HStack(spacing: 2){
                                        AppIcon(icon: .fileAttachment, color: Color.actionColorPrimaryFg)
                                        Text(ResourceManager.localized("uploadText"))
                                            .foregroundColor(Color.actionColorPrimaryFg)
                                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(Color.actionColorPrimaryBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.actionColorPrimaryBorder, lineWidth: 1)
                                    )
                                    .cornerRadius(6)
                                    .contentShape(Rectangle()) // 👈 ensures the full area is tappable
                                    .disabled(isFormElementDisabled)
                                    .opacity(isFormElementDisabled ? 0.6 : 1.0)
                                }
                            }
                            if !formDetails.isRequired {
                                Button(action: {
                                    if let onFormSubmit = self.onFormSubmit {
                                        onFormSubmit(formDetails, message.id, "", nil, nil)
                                    }
                                }) {
                                    Text(ResourceManager.localized("skip"))
                                        .foregroundColor(Color.actionColorPrimaryBg)
                                        .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                                        .frame(minHeight: 32)
                                        .padding(.horizontal, 14)
                                }
                                .background(Color.bgPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.actionColor300, lineWidth: 1)
                                )
                                .cornerRadius(8)
                                .contentShape(Rectangle()) // 👈 ensures the full area is tappable
                                .disabled(isFormElementDisabled)
                                .opacity(isFormElementDisabled ? 0.6 : 1.0)
                            }
                            
                            if !(formDetails.type == .getFileInput && (message.files ?? []).isEmpty) && formDetails.subType != .buttons && formDetails.subType != .boolean && formDetails.subType != .buttonsBranch {
                                Spacer()
                                Button(action: {
                                    guard self.formErrorMsg.isEmpty else { return }
                                    let (valid, error) = (formDetails.type == .getPickerInput || formDetails.type == .branchOnPickerInput) ? validateWorkflowPickerInput(selectedItems: formPickerValue, formDetails: formDetails) : validateWorkFormInput(text: formValue, formDetails: formDetails)
                                    if valid {
                                        if let onFormSubmit = self.onFormSubmit {
                                            onFormSubmit(formDetails, message.id, formValue.trimmingCharacters(in: .whitespacesAndNewlines), formPickerValue, message.files)
                                        }
                                    } else {
                                        isFormValid = valid
                                        formErrorMsg = error
                                    }
                                }) {
                                    Text(ResourceManager.localized("submit"))
                                        .foregroundColor(Color.actionColorPrimaryFg)
                                        .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                                        .frame(minHeight: 32)
                                        .padding(.horizontal, 14)
                                }
                                .background(Color.actionColorPrimaryBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.actionColorPrimaryBorder, lineWidth: 1)
                                )
                                .cornerRadius(6)
                                .contentShape(Rectangle()) // 👈 ensures the full area is tappable
                                .disabled(isFormElementDisabled)
                                .opacity(isFormElementDisabled ? 0.6 : 1.0)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                if let files = message.files, !files.isEmpty, !message.isRetracted {
                    filesView(files: files)
                }
            }
            
            if message.deliveryStatus != .notSent && message.deliveryStatus != .uploading && message.deliveryStatus != .toSent {
                HStack(spacing: 4) {
                    Text(message.timeLabel)
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                        .foregroundColor(message.userType == .agent || message.isRetracted ? .textTertiary : Color.textPrimaryOnBrand)
                    
                    if message.isReplaced && !message.isRetracted {
                        HStack(spacing: 4) {
                            Text("•")
                            Text(ResourceManager.localized("edited"))
                        }
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                        .foregroundColor(message.userType == .agent ? .textTertiary : .textPrimaryOnBrand)
                    }
                    
                    if message.userType == .customer && (message.deliveryStatus == .sent) {
                        AppIcon(icon: .tick, size: FontSize.medium, color: message.isRetracted ? .textTertiary : .textPrimaryOnBrand)
                    }
                }
            }
            
            if message.userType == .customer {
                if message.deliveryStatus == .toSent {
                    Text(ResourceManager.localized("sending"))
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                        .foregroundColor(.textPrimaryOnBrand)
                } else if message.deliveryStatus == .uploading {
                    HStack {
                        Text(ResourceManager.localized("uploading"))
                    }
                    .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                    .foregroundColor(Color.textPrimaryOnBrand)
                }
            }
        }
        .sheet(isPresented: $canShowCreateTicketWeb) {
                            SchedulerBottomSheet(
                                url: "\(WidgetStorageManager.getBrandUrl() ?? "")/support/create",
                                onDismiss: { canShowCreateTicketWeb = false },
                                onEventScheduled: { eventUri in },
                                forCreateForm: true
                            )
                        }
    }
    
    @ViewBuilder
    private func filesView(files: [File]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(files, id: \.url) { file in
                if file.disposition == "attachment" && message.formDetails?.type != .getFileInput {
                    attachmentView(file: file, deliveryStatus: message.deliveryStatus)
                } else if (message.type == .image || message.fieldValueDetails?.fieldValueType == "file") && file.disposition == "inline" {
                    if message.deliveryStatus == .uploading {
                        // Show loading placeholder while uploading
                        ZStack {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 120)
                                .cornerRadius(10)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .bgBrandSolid))
                                .scaleEffect(2)
                        }
                        .frame(maxWidth: 252, minHeight: 120)
                    } else if message.deliveryStatus == .notSent {
                        // Show refresh icon for failed upload
                        ZStack {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 120)
                                .cornerRadius(10)
                            
                            Button(action: {
                                if let retryClickHandler = self.onRetryClick {
                                    retryClickHandler(message.id)
                                }
                            }) {
                                AppIcon(icon: .refresh, size: FontSize.extralarge, color: .fgWhite)
                            }
                        }
                        .frame(maxWidth: 252, minHeight: 120)
                    } else {
                        URLImage(url: file.url)
                    }
                }
            }
        }
    }
    
    private func attachmentView(file: File, deliveryStatus: DeliveryStatus) -> some View {
        HStack(spacing: 6) {
            if deliveryStatus == .uploading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .bgBrandSolid))
                    .frame(width: 20, height: 20)
            } else {
                AppIcon(icon: .attachment1, size: FontSize.large)
            }
            Text(file.name)
                .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(Color.textSecondary)
            if let fileSize = Int(file.size) {
                Text("(\(convertToFormattedSize(fileSize)))")
                    .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                    .foregroundColor(Color.textSecondary)
            }
            if message.deliveryStatus != .notSent && message.deliveryStatus != .uploading {
                Button(action: {
                    downloadFile(from: file.url, fileName: file.name)
                }) {
                    AppIcon(icon: .download, size: FontSize.large)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(height: 36)
        .background(Color.bgPrimary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.borderSecondary, lineWidth: 1)
        )
        .shadow(
            color: Color(red: 16/255, green: 24/255, blue: 40/255).opacity(0.13),
            radius: 2,
            x: 0,
            y: 1
        )
    }
    
    private func htmlMessageView(_ textContent: String) -> some View {
        HTMLContentView(html: textContent)
            .font(.system(size: FontSize.medium, weight: .regular))
            .foregroundColor(message.userType == .agent ? .textSecondary : .textPrimaryOnBrand)
    }
    
    @ViewBuilder
    private func notificationMsg<Content: View>(content: Content) -> some View {
        content
            .foregroundColor(Color.textSecondary)
            .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
            .padding(8)
            .background(Color.bgTertiary)
            .cornerRadius(16)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .padding(.horizontal, 24)
            .lineSpacing(6)
    }
    
    func downloadFile(from urlString: String, fileName: String) {
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let _ = error {
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                return
            }
            guard let tempURL = tempURL else { return }
            
            // Copy into temp with correct filename & extension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: tempURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    openFile(destinationURL)
                }
            } catch {
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
            }
        }
        task.resume()
    }
    
    @ViewBuilder
    private func renderFormField(formDetails: FormDetails) -> some View {
        switch (formDetails.type, formDetails.subType) {
        case (.getCustomerDetails, .name),
            (.getCustomerDetails, .email),
            (.getCustomerDetails, .phone),
            (.getTextInput, .text),
            (.getTextInput, .regex),
            (.getTextInput, .url):
            SingleLineTextFieldView(
                placeholder: formDetails.placeholder,
                validation: { text in
                    let (valid, error) = validateWorkFormInput(text: text, formDetails: formDetails)
                    formErrorMsg = error
                    isFormValid = valid
                    return valid
                },
                updateEnteredText: { text in
                    formValue = text
                },
                text: Binding(
                    get: { formValue },
                    set: { newText in
                        formValue = newText
                    }
                ),
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getTextInput, .number):
            NumericFieldView(
                value: Binding(
                    get: { formValue },
                    set: { newText in
                        formValue = newText
                    }
                ),
                placeholder: formDetails.placeholder,
                validation: { text in
                    let (valid, error) = validateWorkFormInput(text: text, formDetails: formDetails)
                    formErrorMsg = error
                    isFormValid = valid
                    return valid
                },
                updateEnteredText: { text in
                    formValue = text
                },
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getTextInput, .decimal):
            DecimalFieldView(
                value: Binding(
                    get: { formValue },
                    set: { newText in
                        formValue = newText
                    }
                ),
                placeholder: formDetails.placeholder,
                validation: { text in
                    let (valid, error) = validateWorkFormInput(text: text, formDetails: formDetails)
                    formErrorMsg = error
                    isFormValid = valid
                    return valid
                },
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getTextInput, .date):
            let minDate = formDetails.validate?.min ?? AppConstant.minMaxDateRange["datetime"]?.first ?? ""
            let maxDate = formDetails.validate?.max ?? AppConstant.minMaxDateRange["datetime"]?.last ?? ""
            DateFieldView(
                placeholder: formDetails.placeholder,
                minDate: minDate,
                maxDate: maxDate,
                selectedDate: formValue.isEmpty ? nil : .some(formValue),
                updateSelectedDate: { selectedDate in
                    if let dateString = selectedDate {
                        formValue = dateString
                    } else {
                        formValue = ""
                    }
                },
                validation: { date in
                    let (valid, error) = validateWorkFormInput(
                        text: date ?? "",
                        formDetails: formDetails
                    )
                    formErrorMsg = error
                    isFormValid = valid
                    return valid
                },
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getTextInput, .dateTime):
            let minDate = formDetails.validate?.min ?? AppConstant.minMaxDateRange["datetime"]?.first ?? ""
            let maxDate = formDetails.validate?.max ?? AppConstant.minMaxDateRange["datetime"]?.last ?? ""
            DateTimeFieldView(
                placeholder: formDetails.placeholder,
                minDate: minDate,
                maxDate: maxDate,
                selectedDateTime: formValue.isEmpty ? nil : .some(formValue),
                updateSelectedDateTime: { selectedDate in
                    if let dateString = selectedDate {
                        formValue = dateString
                    } else {
                        formValue = ""
                    }
                },
                validation: { date in
                    let (valid, error) = validateWorkFormInput(
                        text: date ?? "",
                        formDetails: formDetails
                    )
                    formErrorMsg = error
                    isFormValid = valid
                    return valid
                },
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getTextInput, .textArea):
            TextAreaFieldView(
                placeholder: formDetails.placeholder,
                text: Binding(
                    get: { "" },
                    set: { text in
                        let (valid, error) = validateWorkFormInput(text: text, formDetails: formDetails)
                        formErrorMsg = error
                        isFormValid = valid
                        formValue = text
                    }
                ),
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getPickerInput, .dropdown):
            SingleSelectDropdownField(
                placeholder: formDetails.placeholder,
                updateSelectedItem: { selectedItem in
                    formPickerValue = selectedItem.map { [$0] } ?? []
                },
                validation: { selectedItem in
                    let singleItemArray = selectedItem.map { [$0] } ?? []
                    let (isValid, error) = validateWorkflowPickerInput(selectedItems: singleItemArray, formDetails: formDetails)
                    formErrorMsg = error
                    isFormValid = isValid
                    return isValid
                },
                selectedItem: Binding(
                    get: { formPickerValue.first },
                    set: { newValue in
                        formPickerValue = newValue.map { [$0] } ?? []
                    }
                ),
                fetchItems: getWorkflowDropdownItems(formDetails: formDetails),
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
        case (.getPickerInput, .multiSelect):
            MultiSelectDropdownField(
                placeholder: formDetails.placeholder,
                updateSelectedItem: { items in
                    formPickerValue = items
                },
                validation: { items in
                    let (isValid, error) = validateWorkflowPickerInput(selectedItems: items, formDetails: formDetails)
                    formErrorMsg = error
                    isFormValid = isValid
                    return isValid
                },
                selectedItems: Binding(
                    get: { formPickerValue },
                    set: { formPickerValue = $0 }
                ),
                fetchItems: getWorkflowDropdownItems(formDetails: formDetails),
                errorMessage: $formErrorMsg,
                isValid: $isFormValid
            )
            
        case (.getPickerInput, .buttons),
            (.branchOnPickerInput, .buttonsBranch),
            (.getPickerInput, .boolean):
            if let options = formDetails.options {
                FormOptionView(options: options, onOptionTap: { option in
                    formPickerValue = [option]
                    if let onFormSubmit = self.onFormSubmit {
                        onFormSubmit(formDetails, message.id, "", [option], nil)
                    }
                }, isDisabled: isFormElementDisabled)
            }
        case (.getFileInput, .none):
            if !(message.files ?? []).isEmpty {
                fileInputView(message: message)
            }
            else{
                EmptyView()
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func fileInputView(message: Message) -> some View {
        // Show file input whenever there's a file attached to the form message.
        // Keep actions / progress based on the delivery status so the UI doesn't
        // vanish if the status transitions (e.g. after upload or on scroll/archiving).
        if let file = message.files?.first {

            fileUploadStatusCard(
                fileName: file.name,
                fileSize: file.size,
                state: message.deliveryStatus
            ) {
                formValue = ""
                viewModel.deleteFileAttachment(messageId: message.id)
            }
            .onChange(of: message.attachmentInfo?.token) { token in
                if let fileToken = token {
                    formValue = fileToken
                }
            }
        }
    }
    
    @ViewBuilder
    private func fileUploadStatusCard(
        fileName: String,
        fileSize: String,
        state: DeliveryStatus,
        onActionTap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            // TOP ROW
            HStack(spacing: 0) {
                if state == .uploading {
                    CircularUploadProgressView()
                        .padding(.leading, 2)
                } else {
                    AppIcon(icon: .jpg, color: Color.fgSecondary)
                }
                
                Text(fileName)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .medium))
                    .foregroundColor(.fgSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                
                Spacer()
                
                if state == .uploading {
                    Button(action: onActionTap) {
                        AppIcon(icon: .close, color: Color.fgSecondary)
                    }
                    .padding(.trailing, 2)
                } else {
                    AttachmentPickerView(
                        isEnabled: true,
                        onFilesPicked: { urls in
                            viewModel.uploadFiles(urls, forWorkflowFileInput: true, message: message)
                        },
                        onImagePicked: { image in
                            viewModel.uploadFiles(image, forWorkflowFileInput: true, message: message)
                        }
                    ) {
                        AppIcon(icon: .refresh, color: Color.textSecondary)
                    }
                    .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(Color.bgPrimary)
            .clipShape(
                    RoundedCorner(
                        radius: 12,
                        corners: [.topLeft, .topRight]
                    )
                )
            
            // DIVIDER
            Rectangle()
                .fill(Color.borderSecondary)
                .frame(height: 1)
            
            // BOTTOM ROW
            HStack {
                if let fileSize = Int(fileSize) {
                    Text(convertToFormattedSize(fileSize))
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
                
                if state == .uploading {
                    Text(ResourceManager.localized("uploading"))
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                        .foregroundColor(.actionColorPrimaryBg)
                } else {
                    Button(ResourceManager.localized("removeText"), action: onActionTap)
                        .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                        .foregroundColor(.textErrorPrimary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSecondary, lineWidth: 1)
        )
    }
}
    
    
    struct AgentShortCodeView: View {
        var shortCode: String
        var colorCode: String
        var avatarSize: CGFloat
        
        var body: some View {
            Text(shortCode)
                .font(FontFamily.customFont(size: FontSize.medium, weight: .bold))
                .foregroundColor(Color.fgWhite)
                .frame(width: avatarSize, height: avatarSize)
                .background(colorCode.isEmpty ? Color.utilityBrand100 : Color(hex: colorCode))
                .clipShape(Circle())
        }
    }
    
    struct SchedulerBottomSheet: View {
        let url: String
        let onDismiss: () -> Void
        let onEventScheduled: (String) -> Void
        let forCreateForm: Bool
        
        var body: some View {
            ZStack(alignment: .top) {
                // Background
                Color.bgPrimary
                    .ignoresSafeArea(edges: .bottom)
                
                VStack(spacing: 0) {
                    ZStack {
                        Capsule()
                            .fill(Color.textSecondary.opacity(0.5))
                            .frame(width: 36, height: 5)
                        
                        HStack {
                            Spacer()
                            Button(action: onDismiss) {
                                AppIcon(icon: .close, size: FontSize.semilarge)
                            }
                            .padding(.trailing, 10)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    if forCreateForm {
                        WebViewForCreateTicket(url: URL(string: url)!)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    else{
                        CalendlyWebViewIframe(calendlyUrl: url, onEventScheduled: onEventScheduled)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .ignoresSafeArea(edges: .bottom)
        }
    }

struct WebViewForCreateTicket: UIViewRepresentable {
    
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            
            let js = """
            var hideLauncher = setInterval(function() {
                var button = document.getElementById('boldchat-host');
                if (button) {
                    button.style.display = 'none';
                    clearInterval(hideLauncher);
                }
            }, 500);
            """
            
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
    struct CalendlyWebViewIframe: UIViewRepresentable {
        let calendlyUrl: String
        let onEventScheduled: (String) -> Void
        
        func makeCoordinator() -> Coordinator {
            Coordinator(onEventScheduled: onEventScheduled)
        }
        
        func makeUIView(context: Context) -> WKWebView {
            let contentController = WKUserContentController()
            contentController.add(context.coordinator, name: "iOSHandler")
            
            let config = WKWebViewConfiguration()
            config.userContentController = contentController
            config.preferences.javaScriptEnabled = true
            config.allowsInlineMediaPlayback = true
            
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.scrollView.bounces = false
            webView.isOpaque = false
            webView.backgroundColor = .white
            webView.navigationDelegate = context.coordinator
            
            // Build HTML
            let html = """
        <!doctype html>
        <html lang=\"en\">
        <head>
            <meta charset=\"utf-8\"/>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, user-scalable=no\"/>
            <style>
                html, body { height: 100%; width: 100%; margin: 0; padding: 0; overflow: hidden; background: #ffffff; }
                .container { position: fixed; inset: 0; }
                iframe { border: none; width: 100%; height: 100%; display: block; }
            </style>
        </head>
        <body>
            <iframe id=\"calendly-iframe\" src=\"\(calendlyUrl)\" allow=\"fullscreen\" allowfullscreen></iframe>
            <script>
                function calendlyMessageHandler(e) {
                    var data = e.data;
                    if (typeof data === 'string') {
                        try { data = JSON.parse(data); } catch (_) {}
                    }
                    if (e.origin !== 'https://calendly.com') return;
                    if (data && data.event === 'calendly.event_scheduled') {
                        var uri = (data.payload && data.payload.event && data.payload.event.uri) ? data.payload.event.uri : '';
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSHandler) {
                            window.webkit.messageHandlers.iOSHandler.postMessage(uri);
                        }
                        window.removeEventListener('message', calendlyMessageHandler);
                    }
                }
                window.addEventListener('message', calendlyMessageHandler, false);
            </script>
        </body>
        </html>
        """
            
            // Use embed_domain as baseURL if available
            var baseURL: URL? = nil
            if let comps = URLComponents(string: calendlyUrl),
               let items = comps.queryItems,
               let embedDomain = items.first(where: { $0.name == "embed_domain" })?.value,
               let hostURL = URL(string: "https://\(embedDomain)") {
                baseURL = hostURL
            }
            webView.loadHTMLString(html, baseURL: baseURL)
            return webView
        }
        
        func updateUIView(_ uiView: WKWebView, context: Context) {
            // No-op
        }
        
        class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            let onEventScheduled: (String) -> Void
            init(onEventScheduled: @escaping (String) -> Void) {
                self.onEventScheduled = onEventScheduled
            }
            
            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                if message.name == "iOSHandler", let uri = message.body as? String {
                    onEventScheduled(uri)
                }
            }
        }
    }
    
    
    
    struct CircularUploadProgressView: View {
        
        @State private var isAnimating = false
        
        var body: some View {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 3)
                
                // Progress arc
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(
                        Color.purple,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.0)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .frame(width: 20, height: 20)
            .onAppear {
                isAnimating = true
            }
        }
    }
