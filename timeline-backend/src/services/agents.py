import os
import time
import json
from datetime import datetime, timedelta
from typing import Optional
from anthropic import Anthropic
from exa_py import Exa


def analyze_query(query: str) -> dict:
    """
    Agent 1: Query Analyzer

    Uses Claude to analyze user query and determine:
    - What the user is asking for
    - Best sources/domains to search (if any specific ones)
    - Keywords and search strategy

    Args:
        query: The user's query string

    Returns:
        dict: {
            "intent": str,
            "key_topics": list[str],
            "suggested_domains": list[str] | None,
            "search_query": str
        }
    """
    start_time = time.time()

    try:
        anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")
        if not anthropic_api_key or anthropic_api_key == "your_anthropic_api_key_here":
            raise ValueError("ANTHROPIC_API_KEY not configured in .env file")

        client = Anthropic(api_key=anthropic_api_key)

        system_prompt = """You are a query analysis expert. Your job is to analyze user queries and extract:
1. The user's intent (what they're trying to find out)
2. Key topics/keywords to search for
3. Suggested domains/websites that would be best for this query (if any specific ones are relevant, otherwise return null)
4. An optimized search query for a web search engine

Return ONLY a JSON object with this exact structure:
{
  "intent": "Brief description of what user wants",
  "key_topics": ["topic1", "topic2", "topic3"],
  "suggested_domains": ["domain1.com", "domain2.com"] or null,
  "search_query": "optimized search query"
}"""

        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1024,
            system=system_prompt,
            messages=[
                {"role": "user", "content": f"Analyze this query: {query}"}
            ]
        )

        response_text = response.content[0].text
        analysis = json.loads(response_text)

        execution_time = time.time() - start_time
        print(f"[Agent 1] Query analyzed in {execution_time:.2f}s")
        print(f"[Agent 1] Intent: {analysis['intent']}")
        print(f"[Agent 1] Suggested domains: {analysis['suggested_domains']}")

        return analysis

    except json.JSONDecodeError as e:
        print(f"[Agent 1] Error: Failed to parse Claude response as JSON: {e}")
        # Fallback to basic query structure
        return {
            "intent": query,
            "key_topics": query.split(),
            "suggested_domains": None,
            "search_query": query
        }
    except Exception as e:
        print(f"[Agent 1] Error: {e}")
        raise


def search_with_exa(
    query_analysis: dict,
    start_date: datetime,
    end_date: datetime
) -> dict:
    """
    Agent 2: Exa Search

    Calls Exa API with parameters from query analysis.
    - Uses query_analysis["search_query"] for search
    - Filters by suggested_domains if provided
    - Filters by date range (startPublishedDate, endPublishedDate)
    - Retrieves full text content

    Args:
        query_analysis: Output from Agent 1
        start_date: Start of date range to search
        end_date: End of date range to search

    Returns:
        dict: {
            "results": list[dict],
            "num_results": int,
            "sources": list[str]
        }
    """
    start_time = time.time()

    try:
        exa_api_key = os.getenv("EXA_API_KEY")
        if not exa_api_key:
            raise ValueError("EXA_API_KEY not configured in .env file")

        exa = Exa(api_key=exa_api_key)

        search_query = query_analysis.get("search_query", "")
        suggested_domains = query_analysis.get("suggested_domains")

        # Format dates for Exa API (ISO 8601 format)
        start_date_str = start_date.strftime("%Y-%m-%dT%H:%M:%S.000Z")
        end_date_str = end_date.strftime("%Y-%m-%dT%H:%M:%S.000Z")

        print(f"[Agent 2] Searching Exa for: {search_query}")
        print(f"[Agent 2] Date range: {start_date_str} to {end_date_str}")
        print(f"[Agent 2] Domains filter: {suggested_domains}")

        # Build search parameters
        search_params = {
            "type": "auto",
            "num_results": 10,
            "start_published_date": start_date_str,
            "end_published_date": end_date_str,
            "text": True
        }

        # Add domain filtering if suggested
        if suggested_domains and len(suggested_domains) > 0:
            search_params["include_domains"] = suggested_domains

        # Execute search
        result = exa.search_and_contents(search_query, **search_params)

        # Format results
        formatted_results = []
        sources = []

        for item in result.results:
            formatted_item = {
                "url": item.url,
                "title": item.title,
                "text": item.text[:5000] if item.text else "",  # Limit text to 5000 chars
                "published_date": item.published_date if hasattr(item, 'published_date') else None,
                "author": item.author if hasattr(item, 'author') else None
            }
            formatted_results.append(formatted_item)
            sources.append(item.url)

        execution_time = time.time() - start_time
        print(f"[Agent 2] Found {len(formatted_results)} results in {execution_time:.2f}s")

        return {
            "results": formatted_results,
            "num_results": len(formatted_results),
            "sources": sources
        }

    except Exception as e:
        print(f"[Agent 2] Error: {e}")
        # Return empty results instead of failing
        return {
            "results": [],
            "num_results": 0,
            "sources": [],
            "error": str(e)
        }


def analyze_content(
    original_query: str,
    search_results: dict
) -> str:
    """
    Agent 3: Content Analyzer

    Uses Claude to synthesize search results into concise answer.
    - Reads through all search result content
    - Extracts relevant information for the query
    - Synthesizes concise, accurate answer
    - Only verbose when necessary

    Args:
        original_query: The original user query
        search_results: Output from Agent 2

    Returns:
        str: Final answer to user query
    """
    start_time = time.time()

    try:
        anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")
        if not anthropic_api_key or anthropic_api_key == "your_anthropic_api_key_here":
            raise ValueError("ANTHROPIC_API_KEY not configured in .env file")

        client = Anthropic(api_key=anthropic_api_key)

        # Check if we have results
        if search_results["num_results"] == 0:
            return "No relevant information found for the specified date range. Try expanding the search timeframe or adjusting the query."

        # Build context from search results
        context_parts = []
        for idx, result in enumerate(search_results["results"], 1):
            context_parts.append(f"Source {idx}: {result['title']}")
            context_parts.append(f"URL: {result['url']}")
            if result.get('published_date'):
                context_parts.append(f"Published: {result['published_date']}")
            context_parts.append(f"Content: {result['text'][:3000]}")  # Limit per result
            context_parts.append("---")

        context = "\n".join(context_parts)

        system_prompt = """You are an expert research analyst. Your job is to:
1. Read through the search results provided
2. Extract the most relevant information that answers the user's query
3. Synthesize a concise, accurate answer
4. Be concise by default, only be verbose when the topic requires detailed explanation
5. Always cite sources by including the URLs at the end

Format your response as:
[Your concise answer here with key points]

Sources:
- [URL 1]
- [URL 2]
..."""

        user_message = f"""User Query: {original_query}

Search Results:
{context}

Please analyze these search results and provide a concise answer to the user's query."""

        print(f"[Agent 3] Analyzing {search_results['num_results']} search results...")

        response = client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=4096,
            system=system_prompt,
            messages=[
                {"role": "user", "content": user_message}
            ]
        )

        answer = response.content[0].text

        execution_time = time.time() - start_time
        print(f"[Agent 3] Analysis completed in {execution_time:.2f}s")

        return answer

    except Exception as e:
        print(f"[Agent 3] Error: {e}")
        # Fallback to basic summary
        sources_list = "\n".join([f"- {url}" for url in search_results.get("sources", [])])
        return f"Found {search_results['num_results']} relevant sources:\n\n{sources_list}\n\nError generating detailed analysis: {str(e)}"
