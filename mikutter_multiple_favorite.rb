#-*- coding: utf-8 -*-

require 'twitter'
require 'gtk2'

Plugin.create :multiple_favorite do
  UserConfig[:multiple_favorite_oauth_tokens] ||= {}
  UserConfig[:multiple_favorite_oauth_token_secrets] ||= {}

  @services = {}

  def get_verifier(url)
    dialog = Gtk::Dialog.new("Twitter Authentication",
                             nil,
                             nil,
                             [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                             [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])

    label = Gtk::Label.new
    label.wrap = true
    label.set_markup("<span font_desc='20'>mikutter multiple favorite</span>\n\n" +
                     "新しいアカウントを登録します．\n" +
                     "下記URLにアクセスしてPINコードを入力して下さい．\n\n" +
                     "<a href=\"#{url}\">#{url}</a>\n\n")
    dialog.vbox.add(label)
    entry = Gtk::Entry.new
    hbox = Gtk::HBox.new(false, 10)
    hbox.pack_end(entry, false, false, 0)
    hbox.pack_end(Gtk::Label.new('PIN'), false, false, 0)
    dialog.vbox.add(hbox)
    dialog.show_all

    input = ''
    dialog.run do |response|
      case response
      when Gtk::Dialog::RESPONSE_ACCEPT
        input = entry.text
      end
      dialog.destroy
    end

    return input if input.sub(/[^0-9]/,'') =~ /^[0-9]{7}$/
    nil
  end

  def register_twitter_account
    consumer = OAuth::Consumer.new(CHIConfig::TWITTER_CONSUMER_KEY,
                                   CHIConfig::TWITTER_CONSUMER_SECRET,
                                   :site => 'https://api.twitter.com')
    request_token = consumer.get_request_token 
    oauth_verifier = get_verifier(request_token.authorize_url)

    if oauth_verifier
      access_token = request_token.get_access_token(:oauth_verifier => oauth_verifier)
      if access_token

        Twitter.configure do |c|
          c.consumer_key = CHIConfig::TWITTER_CONSUMER_KEY
          c.consumer_secret = CHIConfig::TWITTER_CONSUMER_SECRET
          c.oauth_token = access_token.token
          c.oauth_token_secret = access_token.secret
        end
        twitter = Twitter.client
        username = twitter.user.screen_name
        @services[username.to_sym] = twitter
        update_oauth(username, access_token.token, access_token.secret)
      end
    end
  end

  def token_registered?(username)
    UserConfig[:multiple_favorite_oauth_tokens][username.to_sym] != nil and
      UserConfig[:multiple_favorite_oauth_token_secrets][username.to_sym] != nil
  end

  def load_twitter_account(username)
    Twitter.configure do |c|
      c.consumer_key = CHIConfig::TWITTER_CONSUMER_KEY
      c.consumer_secret = CHIConfig::TWITTER_CONSUMER_SECRET
      c.oauth_token = UserConfig[:multiple_favorite_oauth_tokens][username.to_sym]
      c.oauth_token_secret = UserConfig[:multiple_favorite_oauth_token_secrets][username.to_sym]
    end
    @services[username.to_sym] = Twitter.client
  end

  def update_oauth(username, token, secret)
    tokens = UserConfig[:multiple_favorite_oauth_tokens].melt
    tokens[username.to_sym] = token
    UserConfig[:multiple_favorite_oauth_tokens] = tokens
    secrets = UserConfig[:multiple_favorite_oauth_token_secrets].melt
    secrets[username.to_sym] = secret
    UserConfig[:multiple_favorite_oauth_token_secrets] = secrets
  end

  def initialize
    unless token_registered?(Service.primary.user.to_s)
      update_oauth(Service.primary.user.to_s, UserConfig[:twitter_token], UserConfig[:twitter_secret])
    end
    UserConfig[:multiple_favorite_oauth_tokens].each do |username, token|
      load_twitter_account(username.to_s)
    end
  end

  command(:multiple_favorite_register_account,
          name: '複垢ふぁぼアカウントを登録',
          icon: File.expand_path(File.join(File.dirname(__FILE__), "register_account.png")),
          condition: lambda{ |opt| true },
          visible: true,
          role: :window) do |opt|
    register_twitter_account
  end

  command(:multiple_favorite,
          name: '複垢ふぁぼ',
          icon: File.expand_path(File.join(File.dirname(__FILE__), "register_account.png")),
          condition: lambda{ |opt| true },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.each do |m|
      @services.each do |username_sym, twitter|
        twitter.favorite(m[:id])
        m.add_favorited_by(User.findbyidname(username_sym.to_s))
      end
    end
  end

  initialize

end

