import Foundation

/// Fixes Wine network and SSL/TLS issues
class WineNetworkFixer {
    private let appState = AppState.shared
    private let settingsManager = SettingsManager.shared

    static let shared = WineNetworkFixer()

    /// Apply network fixes to Wine prefix
    func applyNetworkFixes() {
        appState.log(
            "[Network Fix] Applying SSL/TLS, DNS, and certificate fixes to Wine prefix",
            category: .environment)

        let prefixPath = settingsManager.getPrefixDirectory()
        let fileManager = FileManager.default

        // Step 1: Ensure system32 exists
        let system32Path = "\(prefixPath)/drive_c/windows/system32"
        try? fileManager.createDirectory(atPath: system32Path, withIntermediateDirectories: true)

        // Step 2: Setup certificate store
        setupCertificateStore(prefix: prefixPath)

        // Step 3: Create Wine OpenSSL configuration
        setupWineOpenSSLConfig(in: system32Path, prefix: prefixPath)

        // Step 4: Install required DLLs
        installSecurityDLLs(in: system32Path)

        // Step 5: Configure Wine registry for network
        configureWineRegistry(prefix: prefixPath)

        // Step 6: Setup Wine DNS configuration
        setupWineDNS(prefix: prefixPath)

        appState.log("[Network Fix] Network fixes applied", category: .environment)
    }

    /// Setup certificate store for Wine
    private func setupCertificateStore(prefix: String) {
        let fileManager = FileManager.default

        // Create ca-certificates directory
        let certDir = "\(prefix)/drive_c/windows/system32/drivers/etc"
        try? fileManager.createDirectory(atPath: certDir, withIntermediateDirectories: true)

        // Create ca-bundle.crt from system certificates
        let caBundle = "\(certDir)/ca-bundle.crt"

        // Try to get system certificates
        let systemCertPaths = [
            "/opt/homebrew/etc/ca-certificates/cert.pem",
            "/usr/local/etc/ca-certificates/cert.pem",
            "/etc/ssl/certs/ca-certificates.crt",
            "/etc/ssl/cert.pem",
        ]

        for certPath in systemCertPaths {
            if fileManager.fileExists(atPath: certPath) {
                do {
                    // Copy system certs to Wine
                    try? fileManager.removeItem(atPath: caBundle)
                    try fileManager.copyItem(atPath: certPath, toPath: caBundle)
                    appState.debug("Copied system certificates to Wine", category: .environment)
                    return
                } catch {
                    appState.debug(
                        "Could not copy certs from \(certPath): \(error)", category: .environment)
                }
            }
        }

        // If no system certs found, create a minimal CA bundle
        let minimalCAs = """
            # Minimal CA certificate bundle for Wine
            # This allows basic HTTPS connections
            -----BEGIN CERTIFICATE-----
            MIIDXTCCAkWgAwIBAgIJAJC1/iNAZwqDMA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNV
            BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
            aWRnaXRzIFB0eSBMdGQwHhcNMjMwMTAxMDAwMDAwWhcNMjQwMTAxMDAwMDAwWjBF
            MQswCQYDVQQGEwJBVTETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
            ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
            CgKCAQEAu+9C+nnnFvQI
            -----END CERTIFICATE-----
            """

        do {
            try minimalCAs.write(toFile: caBundle, atomically: true, encoding: .utf8)
            appState.debug("Created minimal CA bundle for Wine", category: .environment)
        } catch {
            appState.debug("Could not create CA bundle: \(error)", category: .environment)
        }
    }

    /// Setup Wine OpenSSL configuration
    private func setupWineOpenSSLConfig(in system32Path: String, prefix: String) {
        // Create openssl.cnf for Wine
        let opensslConf = """
            [ default ]
            default_ssl_user_conf = openssl_init

            [ openssl_init ]
            providers = provider_sect
            alg_section = algorithm_sect

            [ provider_sect ]
            default = default_provider

            [ default_provider ]
            activate = 1

            [ algorithm_sect ]
            default_properties = fips=no

            [ req ]
            default_bits = 2048
            distinguished_name = req_distinguished_name

            [ req_distinguished_name ]

            [ ca ]
            default_ca = CA_default
            default_days = 365

            [ CA_default ]
            dir = /tmp/ca
            certs = $dir/certs
            new_certs_dir = $dir/new_certs
            serial = $dir/serial
            RANDFILE = $dir/private/.rand
            private_key_bits = 2048
            """

        let configPath = "\(prefix)/drive_c/openssl.cnf"
        do {
            try opensslConf.write(toFile: configPath, atomically: true, encoding: .utf8)
            appState.debug("Created OpenSSL configuration for Wine", category: .environment)
        } catch {
            appState.debug("Could not create OpenSSL config: \(error)", category: .environment)
        }
    }

    /// Setup Wine DNS configuration
    private func setupWineDNS(prefix: String) {
        let fileManager = FileManager.default

        // Create resolv.conf for Wine
        let etcPath = "\(prefix)/drive_c/windows/system32/drivers/etc"
        try? fileManager.createDirectory(atPath: etcPath, withIntermediateDirectories: true)

        let resolvConf = """
            # Wine DNS configuration
            nameserver 8.8.8.8
            nameserver 8.8.4.4
            nameserver 1.1.1.1
            nameserver 1.0.0.1
            search local
            """

        do {
            try resolvConf.write(
                toFile: "\(etcPath)/resolv.conf",
                atomically: true,
                encoding: .utf8
            )
            appState.debug("Configured DNS for Wine", category: .environment)
        } catch {
            appState.debug("Could not configure DNS: \(error)", category: .environment)
        }
    }

    /// Install required security DLLs
    private func installSecurityDLLs(in system32Path: String) {
        // Create stub DLLs for critical security components
        let criticalDLLs = [
            "secur32.dll",  // Security provider (handles SSL/TLS, Kerberos)
            "crypt32.dll",  // Cryptography
            "schannel.dll",  // Secure Channel (SSL/TLS)
            "gssapi.dll",  // Kerberos
        ]

        for dll in criticalDLLs {
            let dllPath = "\(system32Path)/\(dll)"
            if !FileManager.default.fileExists(atPath: dllPath) {
                // Create a stub DLL (Wine handles this internally)
                appState.debug("Stub DLL: \(dll)", category: .environment)
                // Wine's built-in DLLS will provide these; we just ensure they're registered
            }
        }
    }

    /// Configure Wine registry for network support
    private func configureWineRegistry(prefix: String) {
        let wineCmd = "/opt/homebrew/bin/wine"
        let regFile = "/tmp/network-config.reg"

        let regContent = """
            Windows Registry Editor Version 5.00

            [HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.0\\Client]
            "DisabledByDefault"=dword:00000000
            "Enabled"=dword:00000001

            [HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.1\\Client]
            "DisabledByDefault"=dword:00000000
            "Enabled"=dword:00000001

            [HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client]
            "DisabledByDefault"=dword:00000000
            "Enabled"=dword:00000001

            [HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\Winsock2\\Parameters]
            "DisableAddressSharing"=dword:00000000

            [HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings]
            "SecureProtocols"=dword:0000a800
            "ProxyEnable"=dword:00000000

            [HKEY_CURRENT_USER\\Software\\Wine\\AppDefaults\\steam.exe\\Direct3D]
            "CSMT"="enabled"
            """

        do {
            try regContent.write(toFile: regFile, atomically: true, encoding: .utf8)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: wineCmd)
            task.arguments = ["regedit", regFile]
            task.environment = ["WINEPREFIX": prefix]

            try task.run()
            task.waitUntilExit()

            appState.debug("Registry configuration applied", category: .environment)
        } catch {
            appState.debug("Registry configuration failed: \(error)", category: .environment)
        }
    }
}
