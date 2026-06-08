import WidgetKit
import SwiftUI

// MARK: - Widget definitions

struct CyberLabSmallWidget: Widget {
    let kind = "CyberLabSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CyberLabProvider()) { entry in
            CyberLabSmallView(entry: entry)
                .widgetBackgroundCompat()
        }
        .configurationDisplayName("Risk Score")
        .description("Shows your current CyberLab risk score and critical findings.")
        .supportedFamilies([.systemSmall])
    }
}

struct CyberLabMediumWidget: Widget {
    let kind = "CyberLabMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CyberLabProvider()) { entry in
            CyberLabMediumView(entry: entry)
                .widgetBackgroundCompat()
        }
        .configurationDisplayName("Security Overview")
        .description("Risk score plus your top open findings.")
        .supportedFamilies([.systemMedium])
    }
}

struct CyberLabLockScreenWidget: Widget {
    let kind = "CyberLabLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CyberLabProvider()) { entry in
            CyberLabLockScreenView(entry: entry)
                .widgetBackgroundCompat()
        }
        .configurationDisplayName("Critical Findings")
        .description("Open critical finding count.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Bundle

@main
struct CyberLabWidgetBundle: WidgetBundle {
    var body: some Widget {
        CyberLabSmallWidget()
        CyberLabMediumWidget()
        CyberLabLockScreenWidget()
    }
}

// MARK: - containerBackground compatibility

private extension View {
    @ViewBuilder
    func widgetBackgroundCompat() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(Color.cyberBackground, for: .widget)
        } else {
            background(Color.cyberBackground)
        }
    }
}
