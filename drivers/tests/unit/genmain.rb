# genmain.rb — append the guarded gcc-mirror main() to a test module.
# Usage: ruby genmain.rb <test_file> — idempotent, strips any prior block.
src = File.read(ARGV[0])
src = src.sub(/\n?\/\* gcc-mirror entry point.*\z/m, "\n")
tests = src.scan(/^void (test_\w+)\(void\)/).flatten
abort "no tests found in #{ARGV[0]}" if tests.empty?
name = File.basename(ARGV[0])
main = ["", "/* gcc-mirror entry point — Ceedling generates its own runner and never",
        " * compiles with UNIT_TEST_HOST_STANDALONE, so no duplicate main(). */",
        "#ifdef UNIT_TEST_HOST_STANDALONE", "int main(void)", "{",
        "    UnityBegin(\"#{name}\");"]
tests.each { |t| main << "    RUN_TEST(#{t});" }
main << "    return UnityEnd();"
main << "}"
main << "#endif"
File.write(ARGV[0], src + main.join("\n") + "\n")
puts "#{name}: #{tests.size} tests embedded"
