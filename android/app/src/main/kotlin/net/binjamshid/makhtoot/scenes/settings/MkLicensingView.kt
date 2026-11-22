package net.binjamshid.makhtoot.scenes.settings

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkLicensingDataSource

@androidx.compose.runtime.Composable
fun MkLicensingView(sections: List<MkLicensingDataSource.Section> = emptyList(), isLoading: Boolean = true) { }
@androidx.compose.runtime.Composable
fun MkLicensingView_fontRow(section: MkLicensingDataSource.Section) { }
val MkLicensingView_dataSource: MkLicensingDataSource
    get() = throw MkNotYetPorted("app.MkLicensingView.dataSource")
@androidx.compose.runtime.Composable
fun MkLicensingView_licenseList() { }
val MkLicensingView_bundled: Any
    get() = throw MkNotYetPorted("app.MkLicensingView.bundled")
val MkLicensingView_catalog: Any
    get() = throw MkNotYetPorted("app.MkLicensingView.catalog")
val MkLicensingView_imported: Any
    get() = throw MkNotYetPorted("app.MkLicensingView.imported")
val MkLicensingView_navTitle: String
    get() = throw MkNotYetPorted("app.MkLicensingView.navTitle")
val MkLicensingView_bundledHeader: String
    get() = throw MkNotYetPorted("app.MkLicensingView.bundledHeader")
val MkLicensingView_catalogHeader: String
    get() = throw MkNotYetPorted("app.MkLicensingView.catalogHeader")
val MkLicensingView_importedHeader: String
    get() = throw MkNotYetPorted("app.MkLicensingView.importedHeader")
val MkLicensingView_nothingToShowLabel: String
    get() = throw MkNotYetPorted("app.MkLicensingView.nothingToShowLabel")

