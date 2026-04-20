"use strict";
// Web search via Tavily — built for AI agents.
// API key required (free tier: 1k/mo at tavily.com).
Object.defineProperty(exports, "__esModule", { value: true });
exports.webSearch = webSearch;
async function webSearch(query, topic) {
    const apiKey = process.env.TAVILY_API_KEY;
    if (!apiKey) {
        return `[web_search] TAVILY_API_KEY not set — cannot search for "${query}".`;
    }
    const payload = {
        api_key: apiKey,
        query,
        search_depth: 'advanced',
        include_answer: true,
        max_results: 5,
        ...(topic && topic !== 'general' ? { topic } : {}),
    };
    const res = await fetch('https://api.tavily.com/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    });
    if (!res.ok)
        return `Web search failed: HTTP ${res.status}`;
    const data = (await res.json());
    const parts = [];
    if (data.answer) {
        parts.push(`Summary: ${data.answer}`);
    }
    if (data.results && data.results.length > 0) {
        parts.push('\nTop results:');
        for (const r of data.results.slice(0, 5)) {
            parts.push(`• ${r.title}: ${r.content.slice(0, 200)}...`);
        }
    }
    return parts.length > 0 ? parts.join('\n') : 'No relevant results found.';
}
