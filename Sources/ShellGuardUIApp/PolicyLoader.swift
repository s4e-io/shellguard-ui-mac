import Foundation
import AppKit
import Yams

// MARK: - Policy Config Model

struct PolicyConfig: Codable {
    struct ModeRules: Codable {
        let allowed: [String]
        let blocked: [String]
    }
    let version: Int
    let modes: [String: ModeRules]
}

// MARK: - Policy Loader

final class PolicyLoader {

    static let configDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ShellGuard")
    }()

    static let fileURL: URL = {
        configDir.appendingPathComponent("policy.yaml")
    }()

    static let logFileURL: URL = {
        configDir.appendingPathComponent("activity.log")
    }()

    static let errorLogURL: URL = {
        configDir.appendingPathComponent("shellguard.log")
    }()

    static func load() -> PolicyConfig? {
        guard let yaml = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        return try? YAMLDecoder().decode(PolicyConfig.self, from: yaml)
    }

    static func ensureDefault() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? defaultYAML.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func openInEditor() {
        NSWorkspace.shared.open(fileURL)
    }

    static func openLog() {
        openFileCreatingIfNeeded(logFileURL)
    }

    static func openErrorLog() {
        openFileCreatingIfNeeded(errorLogURL)
    }

    private static func openFileCreatingIfNeeded(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Default Policy YAML

    static let defaultYAML = """
version: 1

modes:

  custom:
    allowed:
      # Navigation & info
      - ls
      - ll
      - la
      - find
      - pwd
      - tree
      - du
      - df
      - stat
      - file
      # Reading & text processing
      - cat
      - head
      - tail
      - less
      - more
      - grep
      - rg
      - ag
      - wc
      - diff
      - jq
      - yq
      - sort
      - uniq
      - cut
      - tr
      - awk
      - sed
      # Git (read-only operations)
      - git status
      - git diff
      - git log
      - git show
      - git branch
      - git stash list
      # System info
      - echo
      - which
      - type
      - env
      - printenv
      - date
      - whoami
      - id
      - uname
    blocked:
      # Destructive file ops
      - rm
      - rmdir
      - shred
      - dd
      # Privilege escalation
      - sudo
      - su
      - doas
      # Permission changes
      - chmod
      - chown
      - chgrp
      # Network transfer
      - curl
      - wget
      - nc
      - ncat
      - nmap
      # Remote access
      - ssh
      - scp
      - sftp
      - rsync
      - telnet
      - ftp
      # Git danger
      - git push
      - git reset --hard
      - git clean
      # System automation
      - osascript
      - launchctl
      - crontab
      - at
      # Process control
      - kill
      - killall
      - pkill

  dev:
    allowed:
      # Navigation & info
      - ls
      - ll
      - la
      - find
      - pwd
      - tree
      - du
      - df
      - stat
      - file
      # Reading & text processing
      - cat
      - head
      - tail
      - less
      - more
      - grep
      - rg
      - ag
      - wc
      - diff
      - jq
      - yq
      - sort
      - uniq
      - cut
      - tr
      - awk
      - sed
      # Git (full except push/reset --hard)
      - git status
      - git diff
      - git log
      - git show
      - git branch
      - git add
      - git commit
      - git checkout
      - git switch
      - git restore
      - git merge
      - git rebase
      - git stash
      - git tag
      - git fetch
      - git cherry-pick
      - git blame
      - git shortlog
      # Package managers
      - npm
      - npx
      - yarn
      - pnpm
      - bun
      - pip
      - pip3
      - poetry
      - uv
      - cargo
      - go
      - swift build
      - swift test
      - swift run
      - mvn
      - gradle
      - make
      - cmake
      - ninja
      - gem
      - bundle
      - composer
      # Runtimes
      - node
      - python
      - python3
      - ruby
      - java
      - deno
      # Containers
      - docker
      - docker compose
      - docker-compose
      - kubectl
      - helm
      # Build & test tools
      - xcodebuild
      - xcrun
      - swiftlint
      - swiftformat
      - jest
      - pytest
      - mocha
      - vitest
      - rspec
      # System info
      - echo
      - which
      - type
      - env
      - printenv
      - date
      - whoami
      - uname
      - lsof
      - ps
      # File ops (non-recursive only — recursive variants are in blocked list)
      - rm
      - mv
      - cp
      - mkdir
      - touch
    blocked:
      # Network (AI should not make arbitrary outbound calls)
      - curl
      - wget
      - nc
      - ncat
      - nmap
      # Remote access (prevent data exfiltration)
      - ssh
      - scp
      - sftp
      - rsync
      - telnet
      - ftp
      # Privilege escalation
      - sudo
      - su
      - doas
      # Destructive (all recursive rm variants — flag order matters for prefix matching)
      - rm -r
      - rm -rf
      - rm -fr
      - rm --recursive
      - shred
      - dd
      # Permission changes
      - chmod
      - chown
      - chgrp
      # Git danger
      - git push
      - git reset --hard
      - git clean -f
      # System automation
      - osascript
      - launchctl
      - crontab
      # Process danger
      - killall
      - pkill

  read only:
    allowed:
      # Navigation
      - ls
      - ll
      - la
      - find
      - pwd
      - tree
      # File viewing
      - cat
      - head
      - tail
      - less
      - more
      - grep
      - rg
      - ag
      - wc
      - diff
      - stat
      - file
      # Git read-only
      - git status
      - git log
      - git diff
      - git show
      - git branch
      # System info only
      - echo
      - which
      - type
      - date
      - whoami
      - id
      - uname
      - env
      - printenv
      - df
      - du
      - ps
      - uptime
    blocked:
      # Any file modification
      - rm
      - rmdir
      - mv
      - cp
      - touch
      - mkdir
      - ln
      - shred
      - dd
      # Privilege escalation
      - sudo
      - su
      - doas
      # Permission changes
      - chmod
      - chown
      - chgrp
      # All network
      - curl
      - wget
      - nc
      - ncat
      - nmap
      - ssh
      - scp
      - sftp
      - rsync
      - telnet
      - ftp
      # All git writes
      - git push
      - git add
      - git commit
      - git reset
      - git clean
      - git rm
      - git stash drop
      # Package managers (no installs)
      - npm
      - npx
      - yarn
      - pnpm
      - bun
      - pip
      - pip3
      - poetry
      - cargo
      - go get
      # Runtimes (no arbitrary execution)
      - python
      - python3
      - node
      - ruby
      - java
      - deno
      # System automation
      - osascript
      - launchctl
      - crontab
      - at
      # Process control
      - kill
      - killall
      - pkill
      # Launch
      - open
      - xdg-open
      # Truncation bypass
      - ": >"
"""
}
