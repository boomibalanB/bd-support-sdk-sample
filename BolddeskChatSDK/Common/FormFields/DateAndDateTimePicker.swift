import SwiftUI

// Public Date View
public struct DateFieldView: View {
    let placeholder: String
    let minDate: String?
    let maxDate: String?
    let selectedDate: String?
    let updateSelectedDate: (String?) -> Void
    let validation: ((String?) -> Bool)?
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    
    public init(
        placeholder: String,
        minDate: String? = nil,
        maxDate: String? = nil,
        selectedDate: String? = nil,
        updateSelectedDate: @escaping (String?) -> Void,
        validation: ((String?) -> Bool)? = nil,
        errorMessage: Binding<String>,
        isValid: Binding<Bool>
    ) {
        self.placeholder = placeholder
        self.minDate = minDate
        self.maxDate = maxDate
        self.selectedDate = selectedDate
        self.updateSelectedDate = updateSelectedDate
        self.validation = validation
        self._errorMessage = errorMessage
        self._isValid = isValid
    }
    
    public var body: some View {
        DatePickerBase(
            placeholder: placeholder,
            minDate: convertISOStringToDate(from: self.minDate ?? ""),
            maxDate: convertISOStringToDate(from: self.maxDate ?? ""),
            selectedDate: selectedDate,
            updateSelectedDate: updateSelectedDate,
            validation: validation,
            errorMessage: $errorMessage,
            isValid: $isValid,
            includeTime: false
        )
    }
}

// Public DateTime View
public struct DateTimeFieldView: View {
    let placeholder: String
    let minDate: String?
    let maxDate: String?
    let selectedDateTime: String?
    let updateSelectedDateTime: (String?) -> Void
    let validation: ((String?) -> Bool)?
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    
    public init(
        placeholder: String,
        minDate: String? = nil,
        maxDate: String? = nil,
        selectedDateTime: String? = nil,
        updateSelectedDateTime: @escaping (String?) -> Void,
        validation: ((String?) -> Bool)? = nil,
        errorMessage: Binding<String>,
        isValid: Binding<Bool>
    ) {
        self.placeholder = placeholder
        self.minDate = minDate
        self.maxDate = maxDate
        self.selectedDateTime = selectedDateTime
        self.updateSelectedDateTime = updateSelectedDateTime
        self.validation = validation
        self._errorMessage = errorMessage
        self._isValid = isValid
    }

    public var body: some View {
        DatePickerBase(
            placeholder: placeholder,
            minDate: convertISOStringToDate(from: self.minDate ?? ""),
            maxDate: convertISOStringToDate(from: self.maxDate ?? ""),
            selectedDate: selectedDateTime,
            updateSelectedDate: updateSelectedDateTime,
            validation: validation,
            errorMessage: $errorMessage,
            isValid: $isValid,
            includeTime: true
        )
    }
}


// Base date picker field component
private struct DatePickerBase: View {
    var placeholder: String
    var minDate: Date?
    var maxDate: Date?
    var selectedDate: String?
    @State private var showDatePicker: Bool = false
    @State private var tempDate: Date = Date()
    var updateSelectedDate: ((String?) -> Void)
    var validation: ((String?) -> Bool)? = nil
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    @State private var isFocused: Bool = false
    var includeTime: Bool
    
    private var formatter: DateFormatter {
        return includeTime ? dateTimeFormatter : dateFormatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedDate != nil ? selectedDate! : (placeholder))
                    .foregroundColor(selectedDate != nil ? Color.textSecondary : Color.textPlaceholder)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                
                Spacer()
                
                HStack(spacing: 8) {
                    AppIcon(icon: includeTime ? .dateTime : .calender)
                    
                    if selectedDate != nil {
                        Button(action: {
                            updateSelectedDate(nil)
                            if let validate = validation {
                                isValid = validate(nil)
                            }
                        }) {
                            AppIcon(icon: .close)
                        }
                    }
                }
            }
            .padding(10)
            .frame(height: 36)
            .background(Color.bgPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        !isValid ? Color.borderError :
                            (isFocused ? Color.brand200 : Color.borderPrimary),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: !isValid ? (isFocused ? Color.textErrorPrimary.opacity(0.5) : .clear) :
                       (isFocused ? Color.brand200 : Color(red: 16/255, green: 24/255, blue: 40/255).opacity(0.05)),
                radius: !isValid ? (isFocused ? 4 : 0) : (isFocused ? 4 : 2),
                x: 0,
                y: !isValid ? (isFocused ? 0 : 0) : (isFocused ? 0 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
                tempDate = stringToDate(selectedDate ?? "") ?? Date()
                showDatePicker = true
            }
            
            if !isValid {
                Text(errorMessage)
                    .font(FontFamily.customFont(size: FontSize.small, weight: .regular))
                    .foregroundColor(Color.textErrorPrimary)
                    .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            if #available(iOS 16.0, *) {
                if includeTime {
                    DateTimePickerPopup(
                        placeholder: placeholder,
                        selectedDate: $tempDate,
                        minDate: minDate,
                        maxDate: maxDate,
                        onSave: { date in
                            let dateString = formatter.string(from: date)
                            updateSelectedDate(dateString)
                            if let validate = validation {
                                isValid = validate(dateString)
                            }
                        },
                        onClear: {
                            updateSelectedDate(nil)
                            if let validate = validation {
                                isValid = validate(nil)
                            }
                        }
                    )
                    .presentationDetents([.height(includeTime ? 520 : 420)]) // Set fixed height for iOS 16+
                    .presentationDragIndicator(.visible)
                } else {
                    DatePickerPopup(
                        placeholder: placeholder,
                        selectedDate: $tempDate,
                        minDate: minDate,
                        maxDate: maxDate,
                        onSave: { date in
                            let dateString = formatter.string(from: date)
                            updateSelectedDate(dateString)
                            if let validate = validation {
                                isValid = validate(dateString)
                            }
                        },
                        onClear: {
                            updateSelectedDate(nil)
                            if let validate = validation {
                                isValid = validate(nil)
                            }
                        }
                    )
                    .presentationDetents([.height(includeTime ? 520 : 420)]) // Set fixed height for iOS 16+
                    .presentationDragIndicator(.visible)
                }
            } else {
                // Fallback for iOS 14 and 15 (covers half screen)
                if includeTime {
                    DateTimePickerPopup(
                        placeholder: placeholder,
                        selectedDate: $tempDate,
                        minDate: minDate,
                        maxDate: maxDate,
                        onSave: { date in
                            let dateString = formatter.string(from: date)
                            updateSelectedDate(dateString)
                            if let validate = validation {
                                isValid = validate(dateString)
                            }
                        },
                        onClear: {
                            updateSelectedDate(nil)
                            if let validate = validation {
                                isValid = validate(nil)
                            }
                        }
                    )
                } else {
                    DatePickerPopup(
                        placeholder: placeholder,
                        selectedDate: $tempDate,
                        minDate: minDate,
                        maxDate: maxDate,
                        onSave: { date in
                            let dateString = formatter.string(from: date)
                            updateSelectedDate(dateString)
                            if let validate = validation {
                                isValid = validate(dateString)
                            }
                        },
                        onClear: {
                                    updateSelectedDate(nil)
                            if let validate = validation {
                                isValid = validate(nil)
                            }
                        }
                    )
                }
            }
        }
        .onDisappear { isFocused = false } // Set isFocused to false when the sheet is dismissed
    }
}

// Date Popup
struct DatePickerPopup: View {
    let placeholder: String
    @Binding var selectedDate: Date
    let minDate: Date?
    let maxDate: Date?
    let onSave: (Date) -> Void
    let onClear: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: (minDate ?? Date.distantPast)...(maxDate ?? Date.distantFuture),
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .accentColor(Color.actionColorPrimaryBg)
                .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle(placeholder)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    onClear()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Clear").foregroundColor(Color.actionColorPrimaryBg).font(FontFamily.customFont(size: FontSize.large, weight: .semibold))
                },
                trailing: Button(action: {
                    onSave(selectedDate)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done").foregroundColor(Color.actionColorPrimaryBg).font(FontFamily.customFont(size: FontSize.large, weight: .semibold))
                }
            )
        }
    }
}

// DateTime Popup
struct DateTimePickerPopup: View {
    let placeholder: String
    @Binding var selectedDate: Date
    let minDate: Date?
    let maxDate: Date?
    let onSave: (Date) -> Void
    let onClear: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: (minDate ?? Date.distantPast)...(maxDate ?? Date.distantFuture),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .accentColor(Color.actionColorPrimaryBg)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle(placeholder)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    onClear()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Clear").foregroundColor(Color.actionColorPrimaryBg).font(FontFamily.customFont(size: FontSize.large, weight: .semibold))
                },
                trailing: Button(action: {
                    onSave(selectedDate)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done").foregroundColor(Color.actionColorPrimaryBg).font(FontFamily.customFont(size: FontSize.large, weight: .semibold))
                }
            )
        }
    }
}
