/**
 * Shared RSS parsing and utility functions
 */

function parseRSS(xml, sourceName) {
    var entries = []
    var itemRegex = /<(item|entry)>([\s\S]*?)<\/(item|entry)>/gi
    var titleRegex = /<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i
    var linkRegex = /<(link|guid|id)(?:[^>]*href=\"([^\"]+)\")?>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(?:link|guid|id)>/i
    var dateRegex = /<(pubDate|dc:date|updated|published)>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(pubDate|dc:date|updated|published)>/i
    var descRegex = /<(description|summary)>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(description|summary)>/i
    var contentRegex = /<(content:encoded|content)>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/(content:encoded|content)>/i
    
    var match
    while ((match = itemRegex.exec(xml)) !== null) {
        var itemContent = match[2]
        var titleMatch = itemContent.match(titleRegex)
        var linkMatch = itemContent.match(linkRegex)
        var dateMatch = itemContent.match(dateRegex)
        var descMatch = itemContent.match(descRegex)
        var fullMatch = itemContent.match(contentRegex)
        
        if (titleMatch) {
            var title = titleMatch[1].trim().replace(/<[^>]*>?/gm, '')
            var link = ""
            if (linkMatch) {
                link = linkMatch[2] || linkMatch[3] || ""
                link = link.trim()
            }
            var dateStr = dateMatch ? dateMatch[2].trim() : ""
            var desc = descMatch ? descMatch[2].trim().replace(/<[^>]*>?/gm, '') : ""
            var full = fullMatch ? fullMatch[2].trim().replace(/<[^>]*>?/gm, '') : ""
            
            var indexedContent = (title + " " + desc + " " + full).substring(0, 1024)
            
            entries.push({
                display: title,
                decoration: "news-subscribe",
                category: "RSS",
                url: link,
                subtext: sourceName + " | " + dateStr.replace(" +0000", "").replace("T", " ").split(".")[0],
                description: desc.substring(0, 300),
                indexedContent: indexedContent,
                duplicateId: "rss:" + link,
                index: -1
            })
        }
    }
    return entries
}

function getSourceFilePath(url, baseCachePath) {
    if (!url) return ""
    var hash = 0
    for (var i = 0; i < url.length; i++) {
        hash = ((hash << 5) - hash) + url.charCodeAt(i)
        hash |= 0
    }
    return baseCachePath + "/source_" + Math.abs(hash) + ".json"
}
