module bio.gff3_record;

import std.conv, std.stdio, std.array, std.string, std.exception;
import std.ascii;
import bio.exceptions, bio.gff3_validation, util.esc_char_conv;

/**
 * Represents a parsed line in a GFF3 file.
 */
class Record {
  /**
   * Constructor for the Record object, arguments are passed to the
   * parser_line() method.
   */
  this(string line, RecordValidator validator = EXCEPTIONS_ON_ERROR) {
    parse_line(line, validator);
  }

  /**
   * Parse a line from a GFF3 file and set object values.
   * The line is first split into its parts and then escaped
   * characters are replaced in those fields. If there is no
   * need for record validation, pass NO_VALIDATION as the
   * second argument to this method, or WARNINGS_ON_ERROR if
   * badly formatted records should be skipped but logged to
   * stderr.
   */
  void parse_line(string line, RecordValidator validator = EXCEPTIONS_ON_ERROR) {
    if (!validator(line))
      return;

    extract_fields(line);
    parse_attributes();
  }

  string seqname;
  string source;
  string feature;
  string start;
  string end;
  string score;
  string strand;
  string phase;
  string[string] attributes;

  /**
   * Returns the ID attribute from record attributes.
   */
  @property string id() {
    if ("ID" in attributes)
      return attributes["ID"];
    else
      return null;
  }

  /**
   * Returns the Parent attribute from record attributes
   */
  @property string parent() {
    if ("Parent" in attributes)
      return attributes["Parent"];
    else
      return null;
  }

  /**
   * Returns true if the attribute Is_circular is true for
   * this record.
   */
  @property bool is_circular() {
    if ("Is_circular" in attributes)
      return attributes["Is_circular"] == "true";
    else
      return false;
  }

  private {
    string attributes_field;

    void extract_fields(string line) {
      int next_tab = line.indexOf("\t");
      seqname = replace_url_escaped_chars(line[0..next_tab]);
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      source = replace_url_escaped_chars(line[0..next_tab]);
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      feature = replace_url_escaped_chars(line[0..next_tab]);
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      start = line[0..next_tab];
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      end = line[0..next_tab];
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      score = line[0..next_tab];
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      strand = line[0..next_tab];
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      phase = line[0..next_tab];
      line = line[next_tab+1..$];

      next_tab = line.indexOf("\t");
      if (next_tab == -1)
        attributes_field = line;
      else
        attributes_field = line[0..next_tab];
    }

    void parse_attributes() {
      if (attributes_field[0] != '.') {
        int next_semicolon = 0;
        while(next_semicolon != -1) {
          next_semicolon = attributes_field.indexOf(';');
          string attribute = null;
          if (next_semicolon == -1)
            attribute = attributes_field;
          else {
            attribute = attributes_field[0..next_semicolon];
            attributes_field = attributes_field[next_semicolon+1..$];
          }
          if (attribute == "") continue;
          int next_assign = attribute.indexOf('=');
          auto attribute_name = replace_url_escaped_chars(attribute[0..next_assign]);
          auto attribute_value = replace_url_escaped_chars(attribute[next_assign+1..$]);
          attributes[attribute_name] = attribute_value;
        }
      }
    }
  }
}

unittest {
  writeln("Testing parseAttributes...");

  // Minimal test
  auto record = new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=1");
  assert(record.attributes == [ "ID" : "1" ]);
  // Test splitting multiple attributes
  record = new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=1;Parent=45");
  assert(record.attributes == [ "ID" : "1", "Parent" : "45" ]);
  // Test if first splitting and then replacing escaped chars
  record = new Record(".\t.\t.\t.\t.\t.\t.\t.\tID%3D=1");
  assert(record.attributes == [ "ID=" : "1"]);
  // Test if parser survives trailing semicolon
  record = new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=1;Parent=45;");
  assert(record.attributes == [ "ID" : "1", "Parent" : "45" ]);
  // Test for an attribute with the value of a single space
  record = new Record(".\t.\t.\t.\t.\t.\t.\t.\tID= ;");
  assert(record.attributes == [ "ID" : " " ]);
  // Test for an attribute with no value
  record = new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=;");
  assert(record.attributes == [ "ID" : "" ]);
  // Test if the validator is properly activated
  assertThrown!RecordException(new Record(".\t.\t.\t.\t.\t.\t.\t.\t"));
}

unittest {
  writeln("Testing GFF3 Record...");
  // Test line parsing with a normal line
  auto record = new Record("ENSRNOG00000019422\tEnsembl\tgene\t27333567\t27357352\t1.0\t+\t2\tID=ENSRNOG00000019422;Dbxref=taxon:10116;organism=Rattus norvegicus;chromosome=18;name=EGR1_RAT;source=UniProtKB/Swiss-Prot;Is_circular=true");
  with (record) {
    assert([seqname, source, feature, start, end, score, strand, phase] ==
           ["ENSRNOG00000019422", "Ensembl", "gene", "27333567", "27357352", "1.0", "+", "2"]);
    assert(attributes == [ "ID" : "ENSRNOG00000019422", "Dbxref" : "taxon:10116", "organism" : "Rattus norvegicus", "chromosome" : "18", "name" : "EGR1_RAT", "source" : "UniProtKB/Swiss-Prot", "Is_circular" : "true"]);
  }

  // Test parsing lines with dots - undefined values
  record = new Record(".\t.\t.\t.\t.\t.\t.\t.\t.");
  with (record) {
    assert([seqname, source, feature, start, end, score, strand, phase] ==
           [".", ".", ".", ".", ".", ".", ".", "."]);
    assert(attributes.length == 0);
  }

  // Test parsing lines with escaped characters
  record = new Record("EXON%3D00000131935\tASTD%25\texon%26\t27344088\t27344141\t.\t+\t.\tID=EXON%3D00000131935;Parent=TRAN%3B000000%3D17239");
  with (record) {
    assert([seqname, source, feature, start, end, score, strand, phase] ==
           ["EXON=00000131935", "ASTD%", "exon&", "27344088", "27344141", ".", "+", "."]);
    assert(attributes == ["ID" : "EXON=00000131935", "Parent" : "TRAN;000000=17239"]);
  }

  // Test id() method/property
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=1")).id == "1");
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=")).id == "");
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\t.")).id is null);

  // Test isCircular() method/property
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\t.")).is_circular == false);
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\tIs_circular=false")).is_circular == false);
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\tIs_circular=true")).is_circular == true);

  // Test the Parent() method/property
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\t.")).parent is null);
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\tParent=test")).parent == "test");
  assert((new Record(".\t.\t.\t.\t.\t.\t.\t.\tID=1;Parent=test;")).parent == "test");

  // Test if the validator is properly activated
  assertThrown!RecordException(new Record(".\t..\t.\t.\t.\t.\t.\t."));
}
