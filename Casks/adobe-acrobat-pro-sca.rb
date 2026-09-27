cask "adobe-acrobat-pro-sca" do
  module Utils
    module AdobeAcrobatProSca
      def self.version_url
        "https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/acrobat/current_version.txt"
      end

      def self.app_paths
        [
          "/Applications/Adobe Acrobat/Adobe Acrobat.app",
          "/Applications/Adobe Acrobat DC/Adobe Acrobat.app",
          "/Applications/Adobe Acrobat DC/Adobe Acrobat Pro.app",
          "/Applications/Adobe Acrobat.app",
        ]
      end

      def self.app_path
        app_paths.find { |path| File.directory?(path) }
      end

      def self.app_version(path)
        return unless path

        require "open3"

        output, status = Open3.capture2e(
          "/usr/libexec/PlistBuddy",
          "-c",
          "Print :CFBundleShortVersionString",
          File.join(path, "Contents/Info.plist"),
        )
        return unless status.success?

        output.strip
      end

      def self.installation_mode(path, app_version, manifest_version)
        return :full unless path
        return :stage_only if app_version == manifest_version.to_s

        :update
      end

      def self.full_installer_package
        "Acrobat/Acrobat DC SCA Installer.pkg"
      end

      def self.manifest_update_package
        "AcrobatManifestUpdate.pkg"
      end

      def self.update_url(version)
        no_dots = version.to_s.delete(".")
        "https://ardownload3.adobe.com/pub/adobe/acrobat/mac/AcrobatDC/#{no_dots}/AcrobatSCADCUpd#{no_dots}.dmg"
      end

      def self.current_version
        return @current_version if defined?(@current_version)

        require "net/http"
        require "uri"

        value = fetch(URI(version_url)).strip
        unless value.match?(/\A\d+(?:\.\d+)+\z/)
          raise "Unexpected Adobe Acrobat version: #{value.inspect}"
        end

        @current_version = value.freeze
      end

      def self.fetch(uri, redirects_remaining = 5)
        unless uri.scheme == "https"
          raise "Refusing non-HTTPS Adobe Acrobat version URL: #{uri}"
        end

        request = Net::HTTP::Get.new(uri.request_uri, { "User-Agent" => "Homebrew" })
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl:      true,
          open_timeout: 10,
          read_timeout: 30,
        ) do |http|
          http.request(request)
        end

        case response
        when Net::HTTPSuccess
          response.body.to_s
        when Net::HTTPRedirection
          if redirects_remaining.zero?
            raise "Too many redirects while fetching the Adobe Acrobat version"
          end

          location = response["location"]
          if location.nil? || location.empty?
            raise "Adobe Acrobat version URL redirected without a Location header"
          end

          fetch(URI.join(uri.to_s, location), redirects_remaining - 1)
        else
          raise "Adobe Acrobat version request failed: HTTP #{response.code} #{response.message}"
        end
      end
      private_class_method :fetch
    end
  end

  version Utils::AdobeAcrobatProSca.current_version
  sha256 :no_check

  app_path = Utils::AdobeAcrobatProSca.app_path
  app_version = Utils::AdobeAcrobatProSca.app_version(app_path)
  installation_mode = Utils::AdobeAcrobatProSca.installation_mode(app_path, app_version, version)

  case installation_mode
  when :stage_only
    url Utils::AdobeAcrobatProSca.version_url
  when :update
    url Utils::AdobeAcrobatProSca.update_url(version),
        user_agent: :fake
  else
    url "https://trials.adobe.com/AdobeProducts/APRO/Acrobat_HelpX/osx10/AcrobatSCA_DC_Web_WWMUI.dmg",
        cookies:    { "MM_TRIALS" => "1234" },
        user_agent: :fake
  end

  name "Adobe Acrobat Pro DC"
  desc "View, create, manipulate, print and manage files in Portable Document Format"
  homepage "https://www.adobe.com/acrobat/pdf-reader.html"

  livecheck do
    url Utils::AdobeAcrobatProSca.version_url
    regex(/^(\d+(?:\.\d+)+)$/i)
  end

  conflicts_with cask: "adobe-acrobat-pro"
  depends_on macos: :ventura

  case installation_mode
  when :update
    rename "**/Acrobat*Upd*.pkg", "AcrobatUpdate.pkg"
    pkg "AcrobatUpdate.pkg"
  when :full
    pkg Utils::AdobeAcrobatProSca.full_installer_package
  when :stage_only
    stage_only true
  end

  if installation_mode == :full
    preflight_steps do
      run "/usr/bin/ruby",
          args:           ["-e", <<~'RUBY'],
            require "fileutils"
            require "pathname"

            staged_path = Pathname(ENV.fetch("STAGED_PATH"))
            version = ENV.fetch("VERSION")
            full_package = staged_path.join("Acrobat/Acrobat DC SCA Installer.pkg")
            expanded_path = staged_path.join(".full-installer-version-check")
            update_dmg = staged_path.join(".manifest-update.dmg")
            update_mount = staged_path.join(".manifest-update")
            update_package = staged_path.join("AcrobatManifestUpdate.pkg")

            FileUtils.rm_rf([expanded_path, update_dmg, update_mount, update_package])

            begin
              abort "Could not expand the Acrobat installer package" unless system(
                "/usr/sbin/pkgutil", "--expand-full", full_package.to_s, expanded_path.to_s
              )

              package_versions = Dir.glob(expanded_path.join("**", "PackageInfo")).map do |path|
                contents = File.read(path)
                next unless contents.match?(/\bidentifier="com\.adobe\.acrobat\.[^"]+"/)

                contents[%r{<pkg-info\b[^>]*\sversion="([^"]+)"}, 1]
              end.compact

              unless package_versions.include?(version)
                no_dots = version.delete(".")
                update_url = "https://ardownload3.adobe.com/pub/adobe/acrobat/mac/AcrobatDC/" +
                             no_dots + "/AcrobatSCADCUpd" + no_dots + ".dmg"
                user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Safari/605.1.15"
                abort "Could not download the Acrobat manifest update" unless system(
                  "/usr/bin/curl", "--fail", "--location", "--output", update_dmg.to_s,
                  "--user-agent", user_agent, update_url
                )

                FileUtils.mkdir_p(update_mount)
                abort "Could not mount the Acrobat manifest update" unless system(
                  "/usr/bin/hdiutil", "attach", "-nobrowse", "-readonly", "-mountpoint",
                  update_mount.to_s, update_dmg.to_s
                )

                update_sources = Dir.glob(update_mount.join("**", "Acrobat*Upd*.pkg"))
                abort "Expected one Acrobat update package, found " + update_sources.length.to_s + "." unless update_sources.length == 1

                FileUtils.cp(update_sources.first, update_package)
              end
            ensure
              system("/usr/sbin/diskutil", "eject", update_mount.to_s, out: File::NULL, err: File::NULL)
              FileUtils.rm_rf([expanded_path, update_dmg, update_mount])
            end
          RUBY
          env:            {
            "STAGED_PATH" => "{{staged_path}}",
            "VERSION"     => "{{version}}",
          },
          network_access: true,
          writable_paths: ["{{staged_path}}"]
    end

    postflight_steps do
      if_path_exists "AcrobatManifestUpdate.pkg" do
        run "/usr/bin/ruby",
            args:         ["-e", <<~RUBY, "--", "{{staged_path}}/AcrobatManifestUpdate.pkg"],
              require "fileutils"

              package = ARGV.fetch(0)
              begin
                system("/usr/sbin/installer", "-pkg", package, "-target", "/")
                exit($?&.exitstatus || 1)
              ensure
                FileUtils.rm_f(package)
              end
            RUBY
            env:          {
              "LOGNAME"  => "{{user}}",
              "USER"     => "{{user}}",
              "USERNAME" => "{{user}}",
            },
            sudo:         true,
            print_stdout: true
      end
    end
  end

  uninstall quit: [
    "com.adobe.Acrobat.Pro",
    "com.adobe.distiller",
  ]

  # Destructive cleanup is intentionally reserved for an explicit --zap.
  zap launchctl: [
        "Adobe_Genuine_Software_Integrity_Service",
        "com.adobe.AAM.Startup-1.0",
        "com.adobe.AAM.Updater-1.0",
        "com.adobe.agsservice",
        "com.adobe.ARMDC.Communicator",
        "com.adobe.ARMDC.SMJobBlessHelper",
        "com.adobe.ARMDCHelper.cc24aef4a1b90ed56a725c38014c95072f92651fb65e1bf9c8e43c37a23d420d",
      ],
      pkgutil:   [
        "com.adobe.acrobat.DC.*",
        "com.adobe.AcroServicesUpdater",
        "com.adobe.armdc.app.pkg",
        "com.adobe.PDApp.AdobeApplicationManager.installer.pkg",
      ],
      delete:    [
        "/Applications/Adobe Acrobat/",
        "/Applications/Adobe Acrobat DC/",
      ],
      trash:     [
        "~/Library/Application Support/Adobe/Acrobat",
        "~/Library/Caches/Acrobat",
        "~/Library/Caches/com.adobe.Acrobat.Pro",
        "~/Library/HTTPStorages/com.adobe.Acrobat.Pro",
        "~/Library/HTTPStorages/com.adobe.Acrobat.Pro.binarycookies",
        "~/Library/Preferences/Adobe/Acrobat",
        "~/Library/Preferences/com.adobe.Acrobat.Pro.plist",
        "~/Library/Saved Application State/com.adobe.Acrobat.Pro.savedState",
        "~/Library/WebKit/com.adobe.Acrobat.Pro",
      ]

  caveats <<~EOS
    This cask selects its installer from the current machine state:
      - no Acrobat app: full SCA base installer
      - older Acrobat app: latest unified update package
      - Acrobat at the manifest version: records the Homebrew receipt only

    To preserve the base application for incremental upgrades, a plain
    `brew uninstall --cask #{token}` removes only this cask's Homebrew receipt.
    For a complete removal, use:
      brew uninstall --cask --zap #{token}
  EOS
end
