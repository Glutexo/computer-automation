import Testing

@Test(
    "Live Safari critical flows",
    .enabled(
        if: false,
        "Run `SAFARI_LIVE_TEST_PROFILE=<profile> swift run computer-automation-live-safari-regression` from an authorized terminal instead. SwiftPM's test helper is not a reliable TCC responsible process for Safari Automation."
    )
)
func liveSafariCriticalFlows() {}
