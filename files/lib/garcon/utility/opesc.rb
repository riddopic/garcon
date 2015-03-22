
module OpEsc

  OPERATORS           = %w{
    +@ -@ + - ** * / % ~ <=> << >> < > === == =~ <= >= | & ^ []= []
  }

  OPERATORS_REGEXP    = Regexp.new(
    '(' << OPERATORS.collect { |k| Regexp.escape(k) }.join('|') << ')'
  )

  OPERATORS_ESC_TABLE = {
      "+@"   => "op_plus",
      "-@"   => "op_minus",
      "+"    => "op_add",
      "-"    => "op_sub",
      "**"   => "op_pow",
      "*"    => "op_mul",
      "/"    => "op_div",
      "%"    => "op_mod",
      "~"    => "op_tilde",
      "<=>"  => "op_cmp",
      "<<"   => "op_lshift",  #push?
      ">>"   => "op_rshift",  #pull?
      "<"    => "op_lt",
      ">"    => "op_gt",
      "==="  => "op_case",
      "=="   => "op_equal",
      "=~"   => "op_apply",
      "<="   => "op_lt_eq",
      ">="   => "op_gt_eq",
      "|"    => "op_or",
      "&"    => "op_and",
      "^"    => "op_xor",
      "[]="  => "op_store",
      "[]"   => "op_fetch"
  }

  # Applies operator escape's according to OPERATORS_ESCAPE_TABLE.
  #
  #   OpEsc.escape('-') #=> "op_sub"
  #
  def self.escape(str)
    str.to_s.gsub(OPERATORS_REGEXP){ OPERATORS_ESC_TABLE[$1] }
  end

  def self.method_to_filename(name)
    fname = escape(name)
    fname = fname[0...-1] if fname =~ /[\!\=\?]$/
    fname
  end
end
