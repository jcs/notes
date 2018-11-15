require_relative "spec_helper.rb"

class FormHelperTest
  include SinatraMore::AssetTagHelpers
  include SinatraMore::FormHelpers
  include SinatraMore::FormatHelpers
  include SinatraMore::OutputHelpers
  include SinatraMore::RenderHelpers
  include SinatraMore::TagHelpers
  include SinatraMore::FormHelpers
end

describe SinatraMore::FormHelpers do
  GROUPED_OPTIONS_A = [
   ['North America', [['United States','US'],'Canada']],
   ['Europe', ['Denmark','Germany','France']]
  ]

  GROUPED_OPTIONS_H = {
    'North America' => [['United States','US'], 'Canada'],
    'Europe' => ['Denmark','Germany','France']
  }

  OUTPUT = (<<END
<select name="test"><option></option><optgroup label="North America"><option value="US">United States</option>
<option value="Canada">Canada</option></optgroup>
<optgroup label="Europe"><option value="Denmark">Denmark</option>
<option value="Germany">Germany</option>
<option value="France">France</option></optgroup></select>
END
).strip!

  it "renders a <select> with groups" do
    fht = FormHelperTest.new
    s = fht.select_tag(:test, :groups => GROUPED_OPTIONS_A, :include_blank => true)
    assert_equal OUTPUT, s
  end

  it "renders a <select> from a group of arrays" do
    fht = FormHelperTest.new
    s = fht.select_tag(:test, :groups => GROUPED_OPTIONS_H, :include_blank => true)
    assert_equal OUTPUT, s
  end
end
