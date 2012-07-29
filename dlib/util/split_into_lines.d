module util.split_into_lines;

import std.string, std.stdio, std.conv, std.ascii;
import util.range_with_cache;

/**
 * A string splitter, which defers parsing until front is called.
 * The constructor takes a string, detects what the line terminator
 * is and then when front is called, the next line in the string is
 * detected and retrieved. Also, there is no copying involved, only
 * slicing.
 */
class SplitIntoLines : RangeWithCache!string {
  this(string data) {
    this.data = data;
    this.newline = detect_newline_delim(data);
  }

  protected string next_item() {
    string line = string.init;
    if (!(data is null)) {
      auto nl_index = indexOf(data, newline);
      if (nl_index == -1) {
        // last line
        line = data;
        data = null;
      } else {
        line = data[0..nl_index];
        data = data[(nl_index+newline.length)..$];
      }
    }
    return line;
  }

  private {
    string newline;
    string data;
  }
}

/**
 * Detects the character or a character sequence which is used in the string
 * for line termination.
 */
string detect_newline_delim(string data) {
  // TODO: Implement a better line termination detection strategy
  return std.ascii.newline;
}

unittest {
  writeln("Testing SplitIntoLines...");
  auto lines = new SplitIntoLines("Test" ~ newline ~ "1" ~ newline ~ "2" ~ newline ~ "3");
  assert(lines.empty == false);
  assert(lines.front == "Test"); lines.popFront();
  assert(lines.empty == false);
  assert(lines.front == "1"); lines.popFront();
  assert(lines.empty == false);
  assert(lines.front == "2"); lines.popFront();
  assert(lines.empty == false);
  assert(lines.front == "3"); lines.popFront();
  assert(lines.empty == true);
  
  // Test for correct behavior when newline at the end of the file
  lines = new SplitIntoLines("Test newline at the end" ~ newline);
  assert(lines.empty == false);
  assert(lines.front == "Test newline at the end"); lines.popFront();
  assert(lines.empty == false);
  assert(lines.front == ""); lines.popFront();
  assert(lines.empty == true);

  // Test if it's working with foreach
  lines = new SplitIntoLines("1" ~ newline ~ "2" ~ newline ~ "3" ~ newline ~ "4");
  int i = 1;
  foreach(value; lines) {
    assert(value == to!string(i));
    i++;
  }
}

