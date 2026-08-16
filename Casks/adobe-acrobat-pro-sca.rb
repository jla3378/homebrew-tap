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

      def self.acrobat_package_versions(package_info_paths)
        package_info_paths.each_with_object([]) do |path, versions|
          contents = File.read(path)
          next unless contents.match?(/\bidentifier="com\.adobe\.acrobat\.[^"]+"/)

          versions << contents[/<pkg-info\b[^>]*\sversion="([^"]+)"/, 1]
        end.uniq
      end

      def self.manifest_version_available?(package_versions, manifest_version)
        package_versions.include?(manifest_version.to_s)
      end

      def self.full_installer_requires_update?(package_versions, manifest_version)
        !manifest_version_available?(package_versions, manifest_version)
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
  when :update
    url Utils::AdobeAcrobatProSca.update_url(version),
        user_agent: :fake,
        verified:   "ardownload3.adobe.com/pub/adobe/acrobat/mac/AcrobatDC/"
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
  end

  preflight do
    if installation_mode == :full
      require "fileutils"

      expanded_path = staged_path/".full-installer-version-check"
      FileUtils.rm_rf(expanded_path)

      begin
        system_command "/usr/sbin/pkgutil",
                       args:         ["--expand-full", (staged_path/Utils::AdobeAcrobatProSca.full_installer_package).to_s,
                                       expanded_path.to_s],
                       print_stdout: false

        package_infos = Dir.glob((expanded_path/"**"/"PackageInfo").to_s)
        package_versions = Utils::AdobeAcrobatProSca.acrobat_package_versions(package_infos)
        next unless Utils::AdobeAcrobatProSca.full_installer_requires_update?(package_versions, version)

        update_dmg = staged_path/".manifest-update.dmg"
        update_mount = staged_path/".manifest-update"
        update_package = staged_path/Utils::AdobeAcrobatProSca.manifest_update_package
        FileUtils.rm_rf([update_dmg, update_mount, update_package])

        begin
          system_command "/usr/bin/curl",
                         args:         ["--fail", "--location", "--output", update_dmg.to_s,
                                         "--user-agent", HOMEBREW_USER_AGENT_FAKE_SAFARI,
                                         Utils::AdobeAcrobatProSca.update_url(version)],
                         print_stdout: false

          FileUtils.mkdir_p(update_mount)
          system_command "/usr/bin/hdiutil",
                         args:         ["attach", "-nobrowse", "-readonly", "-mountpoint", update_mount.to_s,
                                         update_dmg.to_s],
                         print_stdout: false

          update_sources = Dir.glob((update_mount/"**"/"Acrobat*Upd*.pkg").to_s)
          raise "Expected one Acrobat update package, found #{update_sources.length}." unless update_sources.length == 1

          FileUtils.cp(update_sources.first, update_package)
        ensure
          system_command "/usr/sbin/diskutil",
                         args:         ["eject", update_mount.to_s],
                         must_succeed: false,
                         print_stdout: false
          FileUtils.rm_rf([update_dmg, update_mount])
        end

      ensure
        FileUtils.rm_rf(expanded_path)
      end
    end
  end

  postflight do
    next unless installation_mode == :full

    require "fileutils"

    update_package = staged_path/Utils::AdobeAcrobatProSca.manifest_update_package
    next unless update_package.exist?

    begin
      current_user = User.current&.to_s
      system_command "/usr/sbin/installer",
                     args:         ["-pkg", update_package.to_s, "-target", "/"],
                     env:          { "LOGNAME" => current_user, "USER" => current_user, "USERNAME" => current_user },
                     print_stdout: true,
                     sudo:         true,
                     sudo_as_root: true
    ensure
      FileUtils.rm_rf(update_package)
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
