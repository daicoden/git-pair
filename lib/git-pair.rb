$bold, $reverse, $red, $reset = "\e[1m", "\e[7m", "\e[91m", "\e[0m"

module GitPair

  VERSION = File.read(File.join(File.dirname(__FILE__), "git-pair", "VERSION")).strip

  class NoMatchingAuthorsError < ArgumentError; end
  class MissingConfigurationError < RuntimeError; end


  module Commands
    def add(name)
      @config_changed = true
      `git config --add git-pair.authors "#{name}"`
    end

    def remove(name)
      @config_changed = true
      `git config --unset-all git-pair.authors "^#{name}$"`
    end

    def set_email_template(email)
      @config_changed = true
      `git config git-pair.email "#{email}"`
    end

    def config_change_made?
      @config_changed
    end

    def switch(abbreviations)
      raise MissingConfigurationError, "Please add some authors first" if Helpers.author_names.empty?
      raise MissingConfigurationError, "Please set the email template first" if Helpers.email_template.empty?

      names = abbreviations.map { |abbrev|
        name = Helpers.author_name_from_alias(abbrev)
        raise NoMatchingAuthorsError, "no authors matched #{abbrev}" if name.nil?
        name
      }
      
      
      sorted_names = names.uniq.sort_by { |name| Helpers.tidy_name(name).split.last }
      `git config user.name "#{sorted_names.map{|n| Helpers.tidy_name(n)}.join(' + ')}"`
      initials = Helpers.email_aliases_from_authors(names.uniq)
      `git config user.email "#{Helpers.email(*initials)}"`
    end

    extend self
  end


  module Helpers
    def display_string_for_config
      "#{$bold}  Email template: #{$reset}" + email("[aa]", "[bb]") + "\n" +
      "#{$bold}     Author list: #{$reset}" + author_names.join("\n                  ")
    end

    def display_string_for_current_info
      "#{$bold}  Current author: #{$reset}" + current_author + "\n" +
      "#{$bold}   Current email: #{$reset}" + current_email + "\n "
    end

    def author_names
      names = `git config --get-all git-pair.authors`.split("\n")
      names.uniq.sort_by { |name| name.split.last }
    end

    def email(*initials_list)
      initials_string = initials_list.map { |initials| "+#{initials}" }.join
      email_template.sub("@", "#{initials_string}@")
    end

    def email_template
      `git config --get git-pair.email`.strip
    end

    def current_author
      `git config --get user.name`.strip
    end

    def current_email
      `git config --get user.email`.strip
    end

    def author_name_from_alias(al)
      author_names.each do |name|
        return name if name =~ /<#{al}>/
      end
      
      author_name_from_abbreviation(al)
    end

    def author_name_from_abbreviation(abbrev)
      # initials
      author_names.each do |name|
        return name if abbrev.downcase == name.split.map { |word| word[0].chr }.join.downcase
      end

      # start of a name
      author_names.each do |name|
        return name if name.gsub(" ", "") =~ /^#{abbrev}/i
      end

      # includes the letters in order
      author_names.detect do |name|
        name =~ /#{abbrev.split("").join(".*")}/i
      end
    end
    
    def email_aliases_from_authors(authors)
      authors.map do |name|
        if name =~ /<([^>]+)>/
          $1
        else
          name.split.map { |word| word[0].chr }.join.downcase
        end
      end
    end

    def tidy_name(author_name)
      author_name.gsub(/<[^>]+>/, '').strip
    end

    def abort(error_message, extra = "")
      super "#{$red}#{$reverse} Error: #{error_message} #{$reset}\n" + extra
    end

    extend self
  end
end
