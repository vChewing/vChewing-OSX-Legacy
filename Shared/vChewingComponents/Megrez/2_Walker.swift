// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

public extension Megrez.Compositor {
  /// 爬軌函式，會更新當前組字器的 walkedNodes。
  ///
  /// 找到軌格陣圖內權重最大的路徑。該路徑代表了可被觀測到的最可能的隱藏事件鏈。
  /// 這裡使用 Cormen 在 2001 年出版的教材當中提出的「有向無環圖的最短路徑」的
  /// 算法來計算這種路徑。不過，這裡不是要計算距離最短的路徑，而是計算距離最長
  /// 的路徑（所以要找最大的權重），因為在對數概率下，較大的數值意味著較大的概率。
  /// 對於 `G = (V, E)`，該算法的運行次數為 `O(|V|+|E|)`，其中 `G` 是一個有向無環圖。
  /// 這意味著，即使軌格很大，也可以用很少的算力就可以爬軌。
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult mutating func walk() -> (walkedNodes: [Megrez.Node], succeeded: Bool) {
    var result = [Megrez.Node]()
    defer { walkedNodes = result }
    guard !spans.isEmpty else { return (result, true) }

    var vertexSpans = [[Vertex]]()
    spans.forEach { _ in
      vertexSpans.append(.init())
    }

    spans.enumerated().forEach { i, span in
      (1 ... max(span.maxLength, 1)).forEach { j in
        guard let theNode = span[j] else { return }
        vertexSpans[i].append(.init(node: theNode))
      }
    }

    let terminal = Vertex(node: .init(keyArray: ["_TERMINAL_"]))
    var root = Vertex(node: .init(keyArray: ["_ROOT_"]))

    vertexSpans.enumerated().forEach { i, vertexSpan in
      vertexSpan.forEach { vertex in
        let nextVertexPosition = i + vertex.node.spanLength
        if nextVertexPosition == vertexSpans.count {
          vertex.edges.append(terminal)
          return
        }
        vertexSpans[nextVertexPosition].forEach { vertex.edges.append($0) }
      }
    }

    root.distance = 0
    root.edges.append(contentsOf: vertexSpans[0])

    var ordered = topologicalSort(root: &root)
    ordered.reversed().enumerated().forEach { j, neta in
      neta.edges.indices.forEach { relax(u: neta, v: &neta.edges[$0]) }
      ordered[j] = neta
    }

    var iterated = terminal
    var walked = [Megrez.Node]()
    var totalLengthOfKeys = 0

    while let itPrev = iterated.prev {
      walked.append(itPrev.node)
      iterated = itPrev
      totalLengthOfKeys += iterated.node.spanLength
    }

    // 清理內容，否則會有記憶體洩漏。
    ordered.removeAll()
    vertexSpans.removeAll()
    iterated.destroy()
    root.destroy()
    terminal.destroy()

    guard totalLengthOfKeys == keys.count else {
      print("!!! ERROR A")
      return (result, false)
    }
    guard walked.count >= 2 else {
      print("!!! ERROR B")
      return (result, false)
    }
    walked = walked.reversed()
    walked.removeFirst()
    result = walked
    return (result, true)
  }
}
