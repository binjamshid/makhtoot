package net.binjamshid.makhtoot.navigation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.stubs.MkProjectImportError

@androidx.compose.runtime.Composable
fun MkRootShellView(nav: MkAppNavigationModel = MkAppNavigationModel(), openURLErrorText: String? = null, restorationProjectIDString: String? = null, didAttemptStateRestoration: Boolean = false, didStartAccessing: url.startAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource(), opened: Any? = null, candidateIDString: Any? = null, candidateID: Any? = null, args: Any? = null, pathFixture: MkPathTextHarnessView.PathFixture, fixtureIndex: Int = 2) { }
suspend fun MkRootShellView_openExternalPackage(url: java.net.URI) { throw MkNotYetPorted("app.MkRootShellView.openExternalPackage") }
suspend fun MkRootShellView_attemptStateRestorationIfNeeded() { throw MkNotYetPorted("app.MkRootShellView.attemptStateRestorationIfNeeded") }
fun MkRootShellView_clearRestorationMarker(id: MkProjectId) { throw MkNotYetPorted("app.MkRootShellView.clearRestorationMarker") }
fun MkRootShellView_openURLErrorBody(error: MkProjectImportError?): String { throw MkNotYetPorted("app.MkRootShellView.openURLErrorBody") }
@androidx.compose.runtime.Composable
fun MkRootShellView_pushedDestination(route: MkRoute) { }
@androidx.compose.runtime.Composable
fun MkRootShellView_sheetContent(route: MkRoute) { }
@androidx.compose.runtime.Composable
fun MkRootShellView_fullScreenCoverContent(route: MkRoute) { }
val MkRootShellView_isRegularWidth: Boolean
    get() = throw MkNotYetPorted("app.MkRootShellView.isRegularWidth")
val MkRootShellView_openURLErrorTitle: String
    get() = throw MkNotYetPorted("app.MkRootShellView.openURLErrorTitle")
val MkRootShellView_openURLErrorOK: String
    get() = throw MkNotYetPorted("app.MkRootShellView.openURLErrorOK")
@androidx.compose.runtime.Composable
fun MkRootShellView_normalContent() { }
@androidx.compose.runtime.Composable
fun MkRootShellView_shell() { }
@androidx.compose.runtime.Composable
fun MkRootShellView_compactShell() { }
@androidx.compose.runtime.Composable
fun MkRootShellView_regularShell() { }
val MkRootShellView_appTitle: String
    get() = throw MkNotYetPorted("app.MkRootShellView.appTitle")
val MkRootShellView_browserSidebarLabel: String
    get() = throw MkNotYetPorted("app.MkRootShellView.browserSidebarLabel")
val MkRootShellView_settingsSidebarLabel: String
    get() = throw MkNotYetPorted("app.MkRootShellView.settingsSidebarLabel")

