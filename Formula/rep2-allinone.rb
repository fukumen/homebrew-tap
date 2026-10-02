class Rep2Allinone < Formula
  desc "p2-php + Caddy + PHP-FPM all-in-one package"
  homepage "https://github.com/fukumen/p2-php"
  version "202610030049"

  keg_only "rep2-allinone用のstatic-phpがバンドルされているためです"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/fukumen/p2-php/releases/download/latest/rep2-allinone-202610030049-php8.5.11-caddy2.11.6-macos-arm64.tar.gz"
      sha256 "6f2b3ebb87c9e611699aaa2cde73380e72331496f96008d11a6fd99c48923ecf"
    else
      url "https://github.com/fukumen/p2-php/releases/download/latest/rep2-allinone-202610030049-php8.5.11-caddy2.11.6-macos-x86_64.tar.gz"
      sha256 "95443998cb40a887bb475fa4b9297c61d1f9d9098697657e6d851e6b91c03c8d"
    end
  end

  BUILD_INFO_TEMPLATE = <<~INFO
VER_REPO_TYPE=rep2-allinone
VER_REPO_HASH=3821724
VER_REPO_LOG=MjAyNi0xMC0wMyAwMDo0OSBkOWFiZDRhIOOBrmdpdGh1YiB3b3JrZmxvd+iAg+aFrua8j+OCjOOCkuS/ruato+OBqOODkOODvOOCuOODp+ODs+OBruaXpeaZguOCkkpTVOOBq+WkieabtAo=
VER_RUN_ID=37029771068
VER_RUN_NUMBER=9
VER_PHP=8.5.11
VER_CADDY=2.11.6
VER_COMPOSER=2.10.3
  INFO

  PHP_LOCAL_INI_TEMPLATE = <<~INI
; rep2-php.ini の値を上書きするユーザー設定ファイルです。
; このファイルは scan-dir へ z-php-local.ini として symlink され、
; rep2-php.ini より後から読み込まれます。
  INI

  PHP_FPM_LOCAL_CONF_TEMPLATE = <<~CONF
; rep2-php-fpm.conf のプール設定を上書きするユーザー設定ファイルです。
; [www] セクションの include から読み込まれます。
  CONF

  CADDYFILE_TEMPLATE = <<~'CADDY'
:{$REP2_PORT:10088} {
    log {
        output stderr
    }
    root * {$REP2_WWW_ROOT}
    php_fastcgi 127.0.0.1:9000
    file_server

    @js_files {
        path *.js
    }
    header @js_files Content-Type "application/javascript; charset=Shift_JIS"

    @css_files {
        path *.css
    }
    header @css_files Content-Type "text/css; charset=Shift_JIS"
}
  CADDY

  DEFAULT_TEMPLATE = <<~DEFAULT
# Default port for rep2-allinone (Caddy)
REP2_PORT=10088
  DEFAULT

  FPMCONF_TEMPLATE = <<~CONF
[global]
error_log = @@ERROR_LOG_PATH@@
log_limit = 8192

[www]
listen = 127.0.0.1:9000
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
catch_workers_output = yes
decorate_workers_output = no
clear_env = no

include = @@CONF_DIR@@/php-fpm-local.conf
  CONF

  def install
    inreplace "p2-php/conf.orig/conf.inc.php", "@@REP2_INSTALL_DIR@@", opt_prefix

    Dir.glob("p2-php/data.orig/*/").each do |dir|
      touch File.join(dir, ".keep")
    end
    prefix.install Dir["*"]

    chmod 0755, prefix/"rep2-allinone"
    chmod 0755, Dir[prefix/"bin/*"]
  end

  post_install_steps do
    mkdir_p "rep2-allinone", base: :etc
    mkdir_p "lib/rep2-allinone/conf", base: :var
    mkdir_p "lib/rep2-allinone/data", base: :var
    mkdir_p "lib/rep2-allinone/ic", base: :var
    mkdir_p "lib/rep2-allinone/user_skin", base: :var
    mkdir_p "etc/php/conf.d", base: :prefix

    write_file "rep2-allinone/build_info", BUILD_INFO_TEMPLATE, base: :etc

    unless_path_exists "rep2-allinone/php-local.ini", base: :etc do
      write_file "rep2-allinone/php-local.ini", PHP_LOCAL_INI_TEMPLATE, base: :etc
    end
    unless_path_exists "rep2-allinone/php-fpm-local.conf", base: :etc do
      write_file "rep2-allinone/php-fpm-local.conf", PHP_FPM_LOCAL_CONF_TEMPLATE, base: :etc
    end
    unless_path_exists "rep2-allinone/Caddyfile", base: :etc do
      write_file "rep2-allinone/Caddyfile", CADDYFILE_TEMPLATE, base: :etc
    end
    unless_path_exists "rep2-allinone/default", base: :etc do
      write_file "rep2-allinone/default", DEFAULT_TEMPLATE, base: :etc
    end

    fpm_conf = FPMCONF_TEMPLATE.gsub("@@ERROR_LOG_PATH@@", "#{HOMEBREW_PREFIX}/var/lib/rep2-allinone/php-fpm.log")
                               .gsub("@@CONF_DIR@@", "#{HOMEBREW_PREFIX}/etc/rep2-allinone")
    write_file "etc/rep2-php-fpm.conf", fpm_conf, base: :prefix

    unless_path_exists "rep2-allinone/secrets.conf", base: :etc do
      run "{{opt_prefix}}/bin/php",
          args: ["-r", "echo 'SECRET_KEY=', bin2hex(random_bytes(32)), PHP_EOL;"],
          stdout_path: "{{etc}}/rep2-allinone/secrets.conf"
      set_permissions "rep2-allinone/secrets.conf", "0600", base: :etc, recursive: false
    end

    symlink "rep2-allinone/php-local.ini", "etc/php/conf.d/z-php-local.ini",
            source_base: :etc, target_base: :prefix, overwrite: true
    symlink "lib/rep2-allinone/conf", "p2-php/conf",
            source_base: :var, target_base: :prefix, overwrite: true
    symlink "lib/rep2-allinone/data", "p2-php/data",
            source_base: :var, target_base: :prefix, overwrite: true
    symlink "lib/rep2-allinone/ic", "p2-php/rep2/ic",
            source_base: :var, target_base: :prefix, overwrite: true
    symlink "lib/rep2-allinone/user_skin", "p2-php/rep2/user_skin",
            source_base: :var, target_base: :prefix, overwrite: true
  end

  def caveats
    <<~EOS
      rep2-allinone は以下の場所にインストールされました:
        #{opt_prefix}

      設定ファイル:
        #{etc}/rep2-allinone/default
        #{etc}/rep2-allinone/Caddyfile
        #{etc}/rep2-allinone/php-local.ini
        #{etc}/rep2-allinone/php-fpm-local.conf

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
