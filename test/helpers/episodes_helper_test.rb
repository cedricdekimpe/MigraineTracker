require "test_helper"

class EpisodesHelperTest < ActionView::TestCase
  test "intensity is written as a number, its colour only reinforcing it, a badge for 9 and 10" do
    assert_nil intensity_mark(nil)
    assert_dom_equal '<span class="font-semibold text-sev-mild" data-severity="mild">2</span>', intensity_mark(2)
    assert_match(/text-sev-moderate/, intensity_mark(4))
    assert_match(/text-sev-severe/, intensity_mark(8))
    assert_match(/bg-sev-extreme/, intensity_mark(9))
    assert_match(/>10</, intensity_mark(10))
  end
end
