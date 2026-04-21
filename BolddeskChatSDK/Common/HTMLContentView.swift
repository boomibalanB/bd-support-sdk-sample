import SwiftUI
internal import SwiftSoup

// Main view to render HTML content
struct HTMLContentView: View {
    let html: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Parse HTML and convert it to an array of RenderableNode
            ForEach(parseHTML(html: html), id: \.id) { node in
                node.view // Each node contains a SwiftUI view
            }
        }
    }
    
    // Parse the HTML and return a list of RenderableNode objects
    private func parseHTML(html: String) -> [RenderableNode] {
        do {
            let doc = try SwiftSoup.parse(html) // Parse HTML into a Document
            let body = doc.body() // Get the body element
            let children = body?.getChildNodes() ?? [] // Extract its children
            return children.flatMap { node in
                (try? renderNodes(node)) ?? []
            }
        } catch {
            return [] // Return empty if parsing fails
        }
    }
    
    // Recursively render a node and its children into RenderableNode views
    private func renderNodes(_ node: Node) throws -> [RenderableNode] {
        var result: [RenderableNode] = []
        
        if let element = node as? Element {
            let tag = element.tagName()
            switch tag {
            case "table":
                let tableView = try renderTable(element)
                result.append(RenderableNode(view: tableView))
                // Handle unordered list <ul>
            case "ul":
                let items = try element.select("li")
                
                let itemViews = try items.map { li in
                    try renderNodes(li)
                }
                
                result.append(RenderableNode(view:
                                                VStack(alignment: .leading, spacing: 4) {
                    ForEach(itemViews.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 4) {
                            Text("• ")
                            // Each li may have multiple views (e.g., text + link)
                            ForEach(itemViews[index].indices, id: \.self) { i in
                                itemViews[index][i].view
                            }
                        }
                    }
                }
                                            ))
                
                // Handle ordered list <ol>
            case "ol":
                let items = try element.select("li")
                
                let itemViews = try items.map { li in
                    try renderNodes(li)
                }
                
                result.append(RenderableNode(view:
                                                VStack(alignment: .leading, spacing: 4) {
                    ForEach(itemViews.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(index + 1). ")
                            // Each li may have multiple views (e.g., text + link)
                            ForEach(itemViews[index].indices, id: \.self) { i in
                                itemViews[index][i].view
                            }
                        }
                    }
                }
                                            ))
                
                // Handle single image <img>
            case "img":
                let src = try element.attr("src")
                if !src.isEmpty {
                    result.append(RenderableNode(view: URLImage(url: src)))
                }
                
            case "pre":
                // Get the raw text content (ignores span tags, but preserves \n)
                let rawText = try element.text()
                
                // Optional: decode HTML entities if needed (rare here)
                let decoded = rawText
                //decodeHTMLEntities(rawText)
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let view = ScrollView(.horizontal) {
                    Text(trimmed)
                        .font(.system(size: FontSize.medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                }
                
                result.append(RenderableNode(view: view))
                return result
                
                // Handle generic containers and inline elements
            case "div", "p", "span", "li":
                if isInlineOnly(element) {
                    let className = try element.className()
                    let styledText = try buildText(from: element)
                    
                    if className.contains("e-img-inner") {
                        let view = styledText
                            .font(.system(size: 14))
                            .fontWeight(.regular)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                            .opacity(0.9)
                            .frame(maxWidth: .infinity)
                        result.append(RenderableNode(view: view))
                    } else {
                        result.append(RenderableNode(view: styledText))
                    }
                    
                }
                else {
                    var inlineViews: [AnyView] = []
                    var inlineGroup: [Node] = []
                    
                    for child in element.getChildNodes() {
                        if let el = child as? Element, el.tagName() == "a" {
                            // Flush collected inline group first
                            if !inlineGroup.isEmpty {
                                let text = try buildTextFromNodes(inlineGroup)
                                inlineViews.append(AnyView(text))
                                inlineGroup.removeAll()
                            }
                            
                            // Render tappable link inline
                            let linkText = try buildText(from: el)
                            let href = try el.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)
                            if let url = URL(string: href) {
                                let linkView = linkText
                                    .foregroundColor(.actionColorPrimaryBg)
                                    .font(.system(size: FontSize.medium, weight: .medium))
                                    .onTapGesture {
                                        UIApplication.shared.open(url)
                                    }
                                inlineViews.append(AnyView(linkView))
                            } else {
                                inlineViews.append(AnyView(linkText))
                            }
                            
                        } else if let el = child as? Element, ["img", "div", "p", "span", "li", "ul", "ol", "pre", "table"].contains(el.tagName()) {
                            // Flush inline group
                            if !inlineGroup.isEmpty {
                                let text = try buildTextFromNodes(inlineGroup)
                                inlineViews.append(AnyView(text))
                                inlineGroup.removeAll()
                            }
                            
                            // Add rendered block-level children
                            let children = try renderNodes(el)
                            inlineViews.append(contentsOf: children.map(\.view))
                            
                        } else {
                            // Accumulate inline nodes (plain text, inline tags)
                            inlineGroup.append(child)
                        }
                    }
                    
                    // Flush final inline group
                    if !inlineGroup.isEmpty {
                        let text = try buildTextFromNodes(inlineGroup)
                        inlineViews.append(AnyView(text))
                    }
                    
                    if !inlineViews.isEmpty {
                        let containsBlockLikeView = element.getChildNodes().contains { node in
                            guard let el = node as? Element else { return false }
                            return ["img", "pre", "ul", "ol", "div", "p", "table"].contains(el.tagName())
                        }
                        
                        if containsBlockLikeView {
                            // Use VStack for block-style layout (e.g., image + text)
                            result.append(
                                RenderableNode(view: VStack(alignment: .leading, spacing: 4) {
                                    ForEach(inlineViews.indices, id: \.self) { i in
                                        inlineViews[i]
                                    }
                                }))
                        } else {
                            // All inline — stack as rows to avoid column-style wrapping
                            // Use zero spacing to avoid extra vertical gaps above and below inline content (e.g., links)
                            result.append(
                                RenderableNode(view: VStack(alignment: .leading, spacing: 0) {
                                    ForEach(inlineViews.indices, id: \.self) { i in
                                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                                            inlineViews[i]
                                        }
                                    }
                                }))
                        }
                    }
                }
                
            // For all other tags, recurse into children
            default:
                for child in element.getChildNodes() {
                    result.append(contentsOf: try renderNodes(child))
                }
            }
            
        } else if let textNode = node as? TextNode {
            // Render plain text nodes
            let trimmed = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(RenderableNode(view: Text(trimmed)))
            }
        }
        return result
    }
    
    // Build a Text view directly from nodes (preserving original attributes)
    private func buildTextFromNodes(_ nodes: [Node]) throws -> Text {
        var result = Text("")
        
        for node in nodes {
            if let textNode = node as? TextNode {
                result = result + Text(textNode.text())
            } else if let element = node as? Element {
                // Check for inline styles on this element
                let styleAttr = try element.attr("style")
                let styleDict = parseStyle(styleAttr)
                
                var styles: [String] = []
                
                // Add tag-based styles
                let tag = element.tagName()
                if ["b", "strong", "em", "i", "u"].contains(tag) {
                    styles.append(tag)
                }
                
                // Add inline styles
                if styleDict["text-decoration"]?.contains("underline") == true {
                    styles.append("text-underline")
                }
                
                // Build text with styles
                let styledText = try buildText(from: element, inheritedStyles: styles)
                result = result + styledText
            }
        }
        
        return result
    }
    
    // Build a Text view with styles inherited from parent nodes
    private func buildText(from element: Element, inheritedStyles: [String] = []) throws -> Text {
        var result = Text("")
        
        // Process this element's own styles first
        var currentStyles = inheritedStyles
        
        // Add tag-based styles for this element
        let tag = element.tagName()
        if ["b", "strong", "em", "i", "u"].contains(tag) {
            currentStyles.append(tag)
        }
        
        // Add inline styles for this element
        let elementStyleAttr = try element.attr("style")
        let elementStyleDict = parseStyle(elementStyleAttr)
        if elementStyleDict["text-decoration"]?.contains("underline") == true {
            currentStyles.append("text-underline")
        }
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                var text = Text(textNode.text())
                
                for style in currentStyles {
                    switch style {
                    case "b", "strong":
                        text = text.bold()
                    case "em", "i":
                        text = text.italic()
                    case "u", "text-underline":
                        text = text.underline()
                    default:
                        break
                    }
                }
                
                result = result + text
                
            } else if let childElement = node as? Element {
                let subText = try buildText(from: childElement, inheritedStyles: currentStyles)
                result = result + subText
            }
        }
        
        return result
    }
    
    // Helper to parse inline style attribute into key-value map
    private func parseStyle(_ style: String) -> [String: String] {
        var styles: [String: String] = [:]
        let declarations = style.split(separator: ";")
        for declaration in declarations {
            let parts = declaration.split(separator: ":").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            if parts.count == 2 {
                styles[parts[0]] = parts[1]
            }
        }
        return styles
    }
    
    // Struct to represent each viewable HTML fragment
    struct RenderableNode: Identifiable {
        let id = UUID()
        let view: AnyView
        
        init<V: View>(view: V) {
            self.view = AnyView(view)
        }
    }
    
    private func isInlineOnly(_ element: Element) -> Bool {
        for child in element.getChildNodes() {
            if let el = child as? Element {
                let tag = el.tagName()
                if !["b", "strong", "i", "em", "u", "span"].contains(tag) {
                    return false
                }
                // Recurse to check children too
                if !isInlineOnly(el) {
                    return false
                }
            }
        }
        return true
    }
    
    private func renderTable(_ tableElement: Element) throws -> AnyView {
        let rows = try tableElement.select("tr")
        var tableRows: [TableRowData] = []
        var isFirstRowHeader = false
        var maxColumns = 0
        
        // Check if first row contains th elements (header)
        if let firstRow = rows.first() {
            let headerCells = try firstRow.select("th")
            isFirstRowHeader = !headerCells.isEmpty()
        }
        
        // First pass: collect all data and find max columns
        for (rowIndex, row) in rows.enumerated() {
            let cells = try row.select("td, th")
            var cellData: [String] = []
            
            for cell in cells {
                let cellText = try cell.text().trimmingCharacters(in: .whitespacesAndNewlines)
                cellData.append(cellText)
            }
            
            maxColumns = max(maxColumns, cellData.count)
            let isHeader = isFirstRowHeader && rowIndex == 0
            tableRows.append(TableRowData(cells: cellData, isHeader: isHeader))
        }
        
        // Calculate column widths based on content
        var columnWidths: [CGFloat] = Array(repeating: 100, count: maxColumns)
        
        for row in tableRows {
            for (index, cell) in row.cells.enumerated() {
                let estimatedWidth = max(CGFloat(cell.count * 8 + 24), 80) // Rough estimation
                columnWidths[index] = max(columnWidths[index], estimatedWidth)
            }
        }
        
        let tableView = ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(tableRows.indices, id: \.self) { rowIndex in
                    let row = tableRows[rowIndex]
                    HStack(spacing: 0) {
                        ForEach(0..<maxColumns, id: \.self) { cellIndex in
                            let cellText = cellIndex < row.cells.count ? row.cells[cellIndex] : ""
                            Text(cellText)
                                .font(row.isHeader ? .system(size: 14, weight: .semibold) : .system(size: 14))
                                .foregroundColor(row.isHeader ? .primary : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: columnWidths[cellIndex], alignment: .leading)
                                .background(
                                    Rectangle()
                                        .fill(row.isHeader ? Color(UIColor.systemGray5) : Color.clear)
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
            .background(
                Rectangle()
                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
            )
            .cornerRadius(8)
        
        return AnyView(tableView)
    }
    
    // Add this data structure to your HTMLContentView struct
    private struct TableRowData {
        let cells: [String]
        let isHeader: Bool
    }
}
