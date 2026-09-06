package main

import "testing"

func TestDetectRepeatedRanges(t *testing.T) {
	cues := []Cue{
		{Start: 0, End: 1, Text: "正常です。"},
		{Start: 1, End: 2, Text: " ちょっと待って。 "},
		{Start: 2, End: 3, Text: "ちょっと待って!"},
		{Start: 3, End: 4, Text: "ちょっと待って"},
		{Start: 4, End: 5, Text: "次です。"},
	}

	ranges := detectRepeatedRanges(cues, 3)
	if len(ranges) != 1 {
		t.Fatalf("got %d repeated ranges, want 1", len(ranges))
	}
	if ranges[0].Start != 1 || ranges[0].End != 4 || ranges[0].Count != 3 {
		t.Fatalf("unexpected repeated range: %+v", ranges[0])
	}
}

func TestDetectRepeatedRangesStopsAcrossLongGap(t *testing.T) {
	cues := []Cue{
		{Start: 0, End: 1, Text: "はい"},
		{Start: 1, End: 2, Text: "はい"},
		{Start: 10, End: 11, Text: "はい"},
	}
	if got := detectRepeatedRanges(cues, 3); len(got) != 0 {
		t.Fatalf("long gap must break a repeated run: %+v", got)
	}
}

func TestReplaceCueRange(t *testing.T) {
	original := []Cue{
		{Start: 0, End: 1, Text: "before"},
		{Start: 1, End: 2, Text: "loop"},
		{Start: 2, End: 3, Text: "loop"},
		{Start: 3, End: 4, Text: "loop"},
		{Start: 4, End: 5, Text: "after"},
	}
	replacement := []Cue{{Start: 1.2, End: 3.8, Text: "recovered"}}
	got := replaceCueRange(original, replacement, 1, 4)
	if len(got) != 3 || got[0].Text != "before" || got[1].Text != "recovered" || got[2].Text != "after" {
		t.Fatalf("unexpected replacement result: %+v", got)
	}
}

func TestEmptyRepairCanRemoveHallucination(t *testing.T) {
	original := []Cue{
		{Start: 0, End: 1, Text: "before"},
		{Start: 1, End: 2, Text: "loop"},
		{Start: 2, End: 3, Text: "loop"},
		{Start: 3, End: 4, Text: "loop"},
		{Start: 4, End: 5, Text: "after"},
	}
	got := replaceCueRange(original, nil, 1, 4)
	if len(got) != 2 || got[0].Text != "before" || got[1].Text != "after" {
		t.Fatalf("unexpected empty repair result: %+v", got)
	}
}

func TestIsUsableTranslationRejectsRefusals(t *testing.T) {
	for _, refusal := range []string{"抱歉，我无法协助", "I'm sorry, I can't help with that", "申し訳ありませんが、できません"} {
		if isUsableTranslation(refusal) {
			t.Fatalf("refusal was accepted as a translation: %q", refusal)
		}
	}
	if !isUsableTranslation("这是正常的字幕翻译。") {
		t.Fatal("normal translation was rejected")
	}
}

func TestByteSize(t *testing.T) {
	if got := byteSize(4 * 1024 * 1024 * 1024); got != "4.0 GiB" {
		t.Fatalf("byteSize = %q, want \"4.0 GiB\"", got)
	}
}

func TestSpeechCoverage(t *testing.T) {
	segments := []SpeechSegment{{Start: 10, End: 14}, {Start: 20, End: 21}}

	if got := speechCoverage(Cue{Start: 10, End: 14}, segments); got < 0.99 {
		t.Fatalf("full coverage = %v, want ~1", got)
	}
	if got := speechCoverage(Cue{Start: 13, End: 16}, segments); got >= 0.5 {
		t.Fatalf("half-covered cue = %v, want < 0.5", got)
	}
	if got := speechCoverage(Cue{Start: 30, End: 33}, segments); got != 0 {
		t.Fatalf("noise cue coverage = %v, want 0", got)
	}
	if got := speechCoverage(Cue{Start: 5, End: 5}, segments); got != 1 {
		t.Fatalf("degenerate cue coverage = %v, want 1 (keep)", got)
	}
}
