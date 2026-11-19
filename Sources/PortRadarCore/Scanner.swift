import Darwin
import Foundation

/// Reads listening TCP sockets straight from the kernel through libproc, the
/// same source `lsof` uses, without spawning a subprocess. Only processes owned
/// by the current user are visible; that is every dev server worth showing.
public enum Scanner {
    public static func scan() -> [Listener] {
        var byPort: [Int: Listener] = [:]
        for pid in allPIDs() {
            let sockets = listeningSockets(pid: pid)
            guard !sockets.isEmpty else { continue }
            let facts = processFacts(pid: pid)
            for (port, address) in sockets {
                if var existing = byPort[port] {
                    // Same port from IPv4 + IPv6, or an fd inherited by a worker
                    // (gunicorn, node cluster): keep the lowest pid, the parent.
                    if !existing.addresses.contains(address) { existing.addresses.append(address) }
                    if pid < existing.process.pid { existing.process = facts }
                    byPort[port] = existing
                } else {
                    byPort[port] = Listener(port: port, addresses: [address], process: facts)
                }
            }
        }
        return byPort.values.sorted { $0.port < $1.port }
    }

    static func allPIDs() -> [pid_t] {
        let estimate = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) / MemoryLayout<pid_t>.size + 64)
        let bytes = pids.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, Int32($0.count))
        }
        guard bytes > 0 else { return [] }
        return pids.prefix(Int(bytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    static func listeningSockets(pid: pid_t) -> [(Int, String)] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / stride + 16)
        let got = fds.withUnsafeMutableBytes {
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
        }
        guard got > 0 else { return [] }

        var result: [(Int, String)] = []
        for fd in fds.prefix(Int(got) / stride) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var info = socket_fdinfo()
            let infoSize = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, infoSize) == infoSize,
                  info.psi.soi_kind == Int32(SOCKINFO_TCP)
            else { continue }
            let tcp = info.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == 1 /* TSI_S_LISTEN */ else { continue }
            let port = Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)))
            result.append((port, address(tcp.tcpsi_ini)))
        }
        return result
    }

    private static func address(_ ini: in_sockinfo) -> String {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        if ini.insi_vflag & UInt8(INI_IPV6) != 0 {
            var addr = ini.insi_laddr.ina_6
            inet_ntop(AF_INET6, &addr, &buffer, socklen_t(buffer.count))
            let text = String(cString: buffer)
            return text == "::" ? "*" : text
        }
        var addr = ini.insi_laddr.ina_46.i46a_addr4
        inet_ntop(AF_INET, &addr, &buffer, socklen_t(buffer.count))
        let text = String(cString: buffer)
        return text == "0.0.0.0" ? "*" : text
    }

    static func processFacts(pid: pid_t) -> ProcessFacts {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        let path = pathLength > 0 ? String(cString: pathBuffer) : ""
        return ProcessFacts(pid: pid, executablePath: path, argv: arguments(pid: pid), cwd: cwd(pid: pid))
    }

    static func cwd(pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    /// `KERN_PROCARGS2`: argc, then the exec path, NUL padding, then argv.
    static func arguments(pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }  // exec path
        while index < size, buffer[index] == 0 { index += 1 }  // padding

        var args: [String] = []
        var start = index
        while index < size, args.count < argc {
            if buffer[index] == 0 {
                args.append(String(decoding: buffer[start..<index], as: UTF8.self))
                start = index + 1
            }
            index += 1
        }
        return args
    }
}
