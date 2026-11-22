package net.binjamshid.makhtoot.mk.persistence.undo

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

object MkCommandCoder {
    fun encode(command: MkCommand): ByteArray { throw MkNotYetPorted("mk-persistence.MkCommandCoder.encode") }
    fun decode(data: ByteArray): MkCommand { throw MkNotYetPorted("mk-persistence.MkCommandCoder.decode") }
}

