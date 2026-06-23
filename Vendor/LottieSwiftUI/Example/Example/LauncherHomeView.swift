// Created by Codex on 6/22/26.

import SwiftUI

#if os(macOS)
import AppKit
#endif

struct LauncherHomeView: View {

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        header

        VStack(alignment: .leading, spacing: 16) {
          sectionHeader(title: "快捷启动", subtitle: "点击图标直接打开本机应用")
          launcherGrid
        }

        VStack(alignment: .leading, spacing: 16) {
          sectionHeader(title: "示例内容", subtitle: "保留原来的 Lottie 示例入口")
          NavigationLink {
            AnimationListView(content: .directory("Samples"))
          } label: {
            sampleCard
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 28)
      .padding(.vertical, 24)
      .frame(maxWidth: 1180, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(background)
    .navigationTitle("快捷启动")
    .toolbarRole(.editor)
  }

  @ViewBuilder
  private var launcherGrid: some View {
    if launchableApps.isEmpty {
      emptyState
    } else {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 18, alignment: .top)], spacing: 22) {
        ForEach(launchableApps) { app in
          Button {
            app.launch()
          } label: {
            LauncherAppTile(app: app)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var sampleCard: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(.white.opacity(0.82))
          .frame(width: 56, height: 56)
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(.black.opacity(0.06), lineWidth: 1)
          )

        Image(systemName: "square.grid.2x2.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(.black.opacity(0.75))
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Lottie 示例库")
          .font(.system(size: 17, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)
        Text("继续浏览动画样例和演示页面")
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(.white.opacity(0.66))
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(.black.opacity(0.05), lineWidth: 1)
    )
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("没有找到可启动的应用")
        .font(.system(size: 17, weight: .semibold, design: .rounded))
      Text("在 macOS 上会自动扫描常见系统应用。")
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(.secondary)
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(.white.opacity(0.55))
    )
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("快捷启动")
            .font(.system(size: 36, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .tracking(-0.02)

          Text("快速打开常用本地应用，只保留图标和名称。")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 16)

        statusPill
      }
    }
  }

  private var statusPill: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color(red: 0.24, green: 0.75, blue: 0.42))
        .frame(width: 8, height: 8)
      Text("本机")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(
      Capsule(style: .continuous)
        .fill(.white.opacity(0.68))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    )
    .overlay(
      Capsule(style: .continuous)
        .stroke(.black.opacity(0.05), lineWidth: 1)
    )
  }

  private func sectionHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
      Text(subtitle)
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(.secondary)
    }
  }

  private var background: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.985, green: 0.984, blue: 0.978),
          Color(red: 0.965, green: 0.968, blue: 0.975),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RadialGradient(
        colors: [
          Color.white.opacity(0.75),
          Color.clear,
        ],
        center: .topLeading,
        startRadius: 20,
        endRadius: 900
      )
      .blendMode(.screen)
    }
    .ignoresSafeArea()
  }

  private var launchableApps: [LauncherApp] {
    LauncherApp.commonApplications
      .compactMap { $0.resolvedApp }
  }
}

private struct LauncherAppTile: View {
  let app: LauncherApp

  @State private var isHovering = false

  var body: some View {
    VStack(spacing: 12) {
      icon

      Text(app.displayName)
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(height: 38, alignment: .top)
    }
    .frame(width: 112, height: 132)
    .padding(.vertical, 4)
    .padding(.horizontal, 2)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(isHovering ? .white.opacity(0.92) : .clear)
    )
    .scaleEffect(isHovering ? 1.03 : 1.0)
    .shadow(color: .black.opacity(isHovering ? 0.10 : 0.04), radius: isHovering ? 16 : 8, x: 0, y: isHovering ? 8 : 4)
    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isHovering)
    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    #if os(macOS)
    .onHover { hovering in
      isHovering = hovering
    }
    #endif
  }

  @ViewBuilder
  private var icon: some View {
    #if os(macOS)
    Image(nsImage: app.icon)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(width: 78, height: 78)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    #else
    ZStack {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.white.opacity(0.75))
        .frame(width: 78, height: 78)

      Image(systemName: app.symbolName)
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    #endif
  }
}

private struct LauncherApp: Identifiable, Hashable {
  let id: String
  let displayName: String
  let launchURL: URL

  #if os(macOS)
  var icon: NSImage {
    let image = NSWorkspace.shared.icon(forFile: launchURL.path)
    image.size = NSSize(width: 128, height: 128)
    return image
  }
  #else
  let symbolName: String
  #endif

  func launch() {
    #if os(macOS)
    NSWorkspace.shared.open(launchURL)
    #endif
  }

  static var commonApplications: [LauncherAppSpec] {
    [
      .init(displayName: "Safari", paths: ["/Applications/Safari.app", "/System/Applications/Safari.app"]),
      .init(displayName: "邮件", paths: ["/System/Applications/Mail.app", "/Applications/Mail.app"]),
      .init(displayName: "信息", paths: ["/System/Applications/Messages.app", "/Applications/Messages.app"]),
      .init(displayName: "备忘录", paths: ["/System/Applications/Notes.app", "/Applications/Notes.app"]),
      .init(displayName: "日历", paths: ["/System/Applications/Calendar.app", "/Applications/Calendar.app"]),
      .init(displayName: "提醒事项", paths: ["/System/Applications/Reminders.app", "/Applications/Reminders.app"]),
      .init(displayName: "音乐", paths: ["/Applications/Music.app", "/System/Applications/Music.app"]),
      .init(displayName: "照片", paths: ["/Applications/Photos.app", "/System/Applications/Photos.app"]),
      .init(displayName: "终端", paths: ["/System/Applications/Utilities/Terminal.app", "/Applications/Utilities/Terminal.app"]),
      .init(displayName: "预览", paths: ["/System/Applications/Preview.app", "/Applications/Preview.app"]),
      .init(displayName: "快捷指令", paths: ["/Applications/Shortcuts.app", "/System/Applications/Shortcuts.app"]),
      .init(displayName: "系统设置", paths: ["/System/Applications/System Settings.app", "/Applications/System Preferences.app"]),
      .init(displayName: "App Store", paths: ["/System/Applications/App Store.app", "/Applications/App Store.app"]),
      .init(displayName: "Finder", paths: ["/System/Library/CoreServices/Finder.app"]),
    ]
  }
}

private struct LauncherAppSpec: Hashable {
  let displayName: String
  let paths: [String]

  var resolvedApp: LauncherApp? {
    #if os(macOS)
    for path in paths {
      if FileManager.default.fileExists(atPath: path) {
        let url = URL(fileURLWithPath: path)
        return LauncherApp(
          id: displayName,
          displayName: displayName,
          launchURL: url
        )
      }
    }
    return nil
    #else
    nil
    #endif
  }
}
