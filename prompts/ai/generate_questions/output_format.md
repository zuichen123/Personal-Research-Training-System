Return ONLY valid JSON object with this schema:
{
  "items":[
    {
      "title":"string",
      "stem":"string",
      "type":"single_choice|multi_choice|short_answer",
      "subject":"string",
      "source":"ai_generated",
      "options":[{"key":"A","text":"...","score":0}],
      "answer_key":["string"],
      "tags":["string"],
      "difficulty":1-5,
      "mastery_level":0-100
    }
  ]
}
