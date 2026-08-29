class Rep2AllinoneAT1110 < Formula
  desc "2chproxy.pl + p2-php + Caddy + PHP-FPM all-in-one package"
  homepage "https://github.com/fukumen/rep2-allinone"
  version "1.1.10"

  on_macos do
    if Hardware::CPU.arm?
      url "https://fukumen.github.io/rep2-allinone/macos/rep2-allinone-1.1.10-php8.5.9-caddy2.11.4+202608291551-macos-arm64.tar.gz"
      sha256 "1405bdd80a32fd2c206b8517a5b8df0043ef73f58559ed01e422cb26437ba89c"
    else
      url "https://fukumen.github.io/rep2-allinone/macos/rep2-allinone-1.1.10-php8.5.9-caddy2.11.4+202608291551-macos-x86_64.tar.gz"
      sha256 "19b7d57476830016fb056e83c2bd2ef8cc4e598d65cafe5341484921ffd1cbed"
    end
  end

  def install
    inreplace "p2-php/conf.orig/conf.inc.php", "@@REP2_INSTALL_DIR@@", opt_prefix

    Dir.glob("p2-php/data.orig/*/").each do |dir|
      touch File.join(dir, ".keep")
    end
    prefix.install Dir["*"]

    chmod 0755, prefix/"rep2-allinone"
    chmod 0755, Dir[prefix/"bin/*"]
  end

  def post_install
    (etc/"rep2-allinone").mkpath
    (var/"lib/rep2-allinone/conf").mkpath
    (var/"lib/rep2-allinone/data").mkpath
    (var/"lib/rep2-allinone/ic").mkpath
    (var/"lib/rep2-allinone/user_skin").mkpath

    unless (etc/"rep2-allinone/php-fpm.conf").exist?
      cp prefix/"conf/php-fpm.conf", etc/"rep2-allinone/php-fpm.conf"
      inreplace etc/"rep2-allinone/php-fpm.conf", "@@ERROR_LOG_PATH@@", "#{var}/lib/rep2-allinone/php-fpm.log"
    end
    unless (etc/"rep2-allinone/Caddyfile").exist?
      cp prefix/"conf/Caddyfile", etc/"rep2-allinone/Caddyfile"
    end
    unless (etc/"rep2-allinone/default").exist?
      cp prefix/"conf/default", etc/"rep2-allinone/default"
    end
    cp prefix/"conf/build_info", etc/"rep2-allinone/build_info"

    secrets_file = etc/"rep2-allinone/secrets.conf"
    unless secrets_file.exist?
      secret_key = `#{prefix}/bin/php -r 'echo bin2hex(random_bytes(32));'`.strip
      secrets_file.write("SECRET_KEY=#{secret_key}\n")
      secrets_file.chmod 0600
    end

    ln_sf var/"lib/rep2-allinone/conf", prefix/"p2-php/conf"
    ln_sf var/"lib/rep2-allinone/data", prefix/"p2-php/data"
    ln_sf var/"lib/rep2-allinone/ic", prefix/"p2-php/rep2/ic"
    ln_sf var/"lib/rep2-allinone/user_skin", prefix/"p2-php/rep2/user_skin"
  end

  def caveats
    <<~EOS
      rep2-allinone は以下の場所にインストールされました:
        #{opt_prefix}

      設定ファイル:
        #{etc}/rep2-allinone/default
        #{etc}/rep2-allinone/Caddyfile
        #{etc}/rep2-allinone/php-fpm.conf

      rep2のデータおよびログ:
        #{var}/lib/rep2-allinone/data
        #{var}/lib/rep2-allinone/conf
        #{var}/lib/rep2-allinone/ic
        #{var}/lib/rep2-allinone/rep2-allinone.log
        #{var}/lib/rep2-allinone/php-fpm.log

      バックグラウンドでサービスを開始する場合 (ログインなしで起動):
        sudo brew services start rep2-allinone

      ログイン中のみサービスを開始する場合:
        brew services start rep2-allinone
    EOS
  end

  service do
    run [opt_prefix/"rep2-allinone"]
    keep_alive true
    working_dir var/"lib/rep2-allinone"
    environment_variables(
      CONF_DIR: etc/"rep2-allinone",
      DATA_BASE_DIR: var/"lib/rep2-allinone",
      REP2_WWW_ROOT: opt_prefix/"p2-php/rep2"
    )
    log_path var/"lib/rep2-allinone/rep2-allinone.log"
    error_log_path var/"lib/rep2-allinone/rep2-allinone.log"
  end
end
