module ApplicationHelper
  MAX_PAGES = 10

  def a_or_an(word)
    word[0].downcase.match(/[aeiou]/) ? "an" : "a"
  end

  def days_ago_in_words(date)
    days = 0
    prefix = ""
    suffix = ""

    if date > Date.today
      if date == Date.tomorrow
        return "tomorrow"
      end

      days = (date - Date.today).to_f.ceil
      prefix = "in "
    elsif date == Date.today
      return "today"
    else
      if date == Date.yesterday
        return "yesterday"
      end

      days = (Date.today - date).to_f.ceil
      suffix = " ago"
    end

    if days > 365
      years = (days / 365.0).floor
      return "#{prefix}about #{years} year#{years == 1 ? "" : "s"}#{suffix}"
    elsif days > 30
      months = (days / (365 / 12.0)).floor
      return "#{prefix}about #{months} month#{months == 1 ? "" : "s"}#{suffix}"
    else
      return "#{prefix}#{days} day#{days == 1 ? "" : "s"}#{suffix}"
    end
  end

  def short_time_ago(at)
    secs = Time.now - at
    if secs < 1
      "now"
    elsif secs < 60
      "1m"
    elsif secs < (60 * 60)
      "#{(secs / 60).floor}m"
    elsif secs < (60 * 60 * 24)
      "#{(secs / 60 / 60).floor}h"
    elsif at.year != Time.now.year
      "#{at.strftime("%b %d %Y")}"
    else
      "#{at.strftime("%b %d")}"
    end
  end

  def flash_messages
    o = ""

    [ :error, :notice, :success ].each do |e|
      if flash[e]
        o << content_tag(:div,
          content_tag(:p, flash[e]),
          { :class => "flash flash-#{e.to_s}" })
        flash.delete(e)
      end
    end

    o
  end

  def page_numbers_for_pagination(max, cur)
    if max <= MAX_PAGES
      return (1 .. max).to_a
    end

    pages = (cur - (MAX_PAGES / 2) + 1 .. cur + (MAX_PAGES / 2) - 1).to_a

    while pages[0] < 1
      pages.push pages.last + 1
      pages.shift
    end

    while pages.last > max
      if pages[0] > 1
        pages.unshift pages[0] - 1
      end
      pages.pop
    end

    if pages[0] != 1
      if pages[0] != 2
        pages.unshift "..."
      end
      pages.unshift 1
    end

    if pages.last != max
      if pages.last != max - 1
        pages.push "..."
      end
      pages.push max
    end

    pages
  end

  def ucfirst(str)
    str[0].upcase << str[1 .. -1].to_s
  end
end
