import Foundation

/// Message activities represent content intended to be shown within a conversational interface; and may contain text, speech and interactive cards.
public struct MessageActivity: Codable, Equatable {
    /// The text content of the message.
    public let text: String?

    /// Format of the message's text.
    public let textFormat: TextFormat?

    /// Locale of the language that should be used to display text within the message.
    public let locale: String?

    /// Indicates how the activity should be spoken via a text-to-speech system.
    public let speak: String?

    /// Indicates whether or not the generator of the activity is anticipating a response.
    public let inputHint: InputHint?

    /// Additional information to include in the message.
    public let attachments: [Attachment]

    /// Layout of the rich card attachments that the message includes.
    public let attachmentLayout: AttachmentLayout?

    /// Contains interactive actions that may be displayed to the user.
    public let suggestedActions: SuggestedActions?

    /// Open-ended value.
    public let value: AnyValue?

    public init(text: String? = nil, textFormat: TextFormat? = nil, value: AnyValue? = nil) {
        self.text = text
        self.textFormat = textFormat
        locale = nil
        speak = nil
        inputHint = nil
        attachments = []
        attachmentLayout = nil
        suggestedActions = nil
        self.value = value
    }
}