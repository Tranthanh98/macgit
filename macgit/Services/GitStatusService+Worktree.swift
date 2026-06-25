import Foundation

extension GitStatusService {
    func worktrees(in repositoryURL: URL) async -> [WorktreeEntry] {
        let output = (try? await runGit(arguments: ["worktree", "list", "--porcelain"], in: repositoryURL)) ?? ""
        let parsed = parseWorktreePorcelain(output)

        var dirtyCounts: [URL: Int] = [:]
        await withTaskGroup(of: (URL, Int).self) { group in
            for entry in parsed {
                group.addTask {
                    let count = await self.dirtyCount(in: entry.path)
                    return (entry.path, count)
                }
            }

            for await (path, count) in group {
                dirtyCounts[path] = count
            }
        }

        return parsed.map { entry in
            WorktreeEntry(
                path: entry.path,
                head: entry.head,
                branch: entry.branch,
                isLocked: entry.isLocked,
                dirtyCount: dirtyCounts[entry.path] ?? -1,
                label: nil
            )
        }
    }

    func dirtyCount(in worktreePath: URL) async -> Int {
        guard let output = try? await runGit(arguments: ["status", "--porcelain"], in: worktreePath) else {
            return -1
        }

        return output.split(separator: "\n").count
    }

    private struct ParsedWorktree {
        let path: URL
        let head: String
        let branch: String?
        let isLocked: Bool
    }

    private func parseWorktreePorcelain(_ output: String) -> [ParsedWorktree] {
        var entries: [ParsedWorktree] = []
        var path: URL?
        var head = ""
        var branch: String?
        var isLocked = false

        func flushCurrentEntry() {
            guard let path else { return }
            entries.append(
                ParsedWorktree(
                    path: path,
                    head: String(head.prefix(7)),
                    branch: branch,
                    isLocked: isLocked
                )
            )
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if line.isEmpty {
                flushCurrentEntry()
                path = nil
                head = ""
                branch = nil
                isLocked = false
                continue
            }

            if line.hasPrefix("worktree ") {
                flushCurrentEntry()
                path = normalizedWorktreeURL(from: String(line.dropFirst("worktree ".count)))
                head = ""
                branch = nil
                isLocked = false
            } else if line.hasPrefix("HEAD ") {
                head = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                let ref = String(line.dropFirst("branch ".count))
                branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
            } else if line == "locked" || line.hasPrefix("locked ") {
                isLocked = true
            }
        }

        flushCurrentEntry()

        return entries
    }

    private func normalizedWorktreeURL(from path: String) -> URL {
        let cleanPath = path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
        return URL(fileURLWithPath: cleanPath, isDirectory: false)
    }
}
