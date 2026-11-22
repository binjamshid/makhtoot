package net.binjamshid.makhtoot.mk.foundation

import java.util.UUID
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/**
 * A phantom-typed UUID wrapper so identifiers for different entity kinds
 * cannot be cross-assigned by the compiler. Ports `Sources/MKFoundation/MKID.swift`.
 *
 * `Tag` never needs a runtime value — it exists only to make `MkId<NodeTag>`
 * and `MkId<ProjectTag>` distinct, non-interchangeable types even though both
 * wrap a UUID.
 *
 * `rawValue` is stored as a `String` (the UUID's canonical string form) rather
 * than `java.util.UUID` — a documented deviation (`ANDROID_SPINE.md` §9):
 * Swift's `Codable` conformance is hand-written as a single-value container
 * around the raw UUID string, and `kotlinx.serialization` has no built-in
 * `UUID` serializer, so mirroring the single-value-string shape directly
 * avoids introducing a custom `KSerializer` for a value that is a plain
 * string on the wire either way.
 *
 * **`@Serializable(with = MkIdSerializer::class)`, not a plain `@Serializable`
 * (real compiler confirmed this is required, corrected against an earlier
 * assumption, `ANDROID_SPINE.md` §9):** the auto-derived serializer plugin
 * tries to resolve a serializer for the phantom `Tag` type parameter itself
 * (`Internal compiler error ... Serializer for element of type
 * net.binjamshid.makhtoot.mk.foundation.MkNodeTag has not been found`),
 * even though `Tag` never appears in any actual stored field. [MkIdSerializer]
 * below sidesteps most of that, but the plugin's child-serializer-resolution
 * pass still eagerly resolves a serializer for whatever concrete `Tag` a
 * given `MkId<Tag>` usage binds (e.g. `MkNodeId = MkId<MkNodeTag>`) even
 * though `MkIdSerializer` never asks for one — an empirically confirmed
 * kotlinx.serialization compiler-plugin quirk for custom serializers on
 * generic types, not a design choice. The fix that actually compiles: every
 * phantom tag type below is *itself* a trivial `@Serializable object`
 * (zero fields, so its own auto-derived serializer is free) rather than an
 * uninstantiable `sealed class` with no subclasses — the tag still "never
 * needs a runtime value" (an `object` has exactly one, unused, instance),
 * it just also needs to exist as a resolvable serializer target.
 */
@Serializable(with = MkIdSerializer::class)
data class MkId<Tag>(val rawValue: String = UUID.randomUUID().toString()) {
    override fun toString(): String = rawValue
}

/** Hand-written serializer for [MkId] — see the class doc comment for why the derived one cannot be used. */
class MkIdSerializer<Tag> : KSerializer<MkId<Tag>> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("MkId", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: MkId<Tag>) {
        encoder.encodeString(value.rawValue)
    }

    override fun deserialize(decoder: Decoder): MkId<Tag> = MkId(decoder.decodeString())
}

/** Phantom tag for `MkNodeId` — identifies one scene-graph node (`mk-model`'s `MkNode`). */
@Serializable
object MkNodeTag

typealias MkNodeId = MkId<MkNodeTag>

/** Phantom tag for `MkProjectId` — identifies one `.makhtoot` project document. */
@Serializable
object MkProjectTag

typealias MkProjectId = MkId<MkProjectTag>

/** Phantom tag for `MkClusterId` — identifies one shaped-text cluster (D-105). */
@Serializable
object MkClusterTag

typealias MkClusterId = MkId<MkClusterTag>
