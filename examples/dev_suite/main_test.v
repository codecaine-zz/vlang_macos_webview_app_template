module main

fn test_text_insights_similarity() {
	insights := compute_text_insights('hello world', 'hello there')
	assert insights.distance >= 1
	assert insights.similarity > 0.5
	assert insights.length_a == 'hello world'.len
	assert insights.length_b == 'hello there'.len
}

fn test_timestamp_insights() {
	insight := analyze_timestamp('2026-07-04T12:30:45Z')
	assert insight.iso.len > 0
	assert insight.weekday.len > 0
	assert insight.unix > 0
	assert insight.relative.len > 0
}
