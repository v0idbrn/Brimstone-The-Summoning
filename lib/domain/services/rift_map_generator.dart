class RiftMapGenerator {
  static List<RiftNode> generate(int floors) {
    final nodes = <RiftNode>[];
    for (var i = 0; i < floors; i++) {
      nodes.add(RiftNode(index: i, type: _pickType(i, floors)));
    }
    return nodes;
  }

  static RiftNodeType _pickType(int index, int total) {
    if (index == total - 1) return RiftNodeType.boss;
    if (index % 3 == 0) return RiftNodeType.elite;
    if (index % 4 == 0) return RiftNodeType.altar;
    return RiftNodeType.combat;
  }
}

class RiftNode {
  final int index;
  final RiftNodeType type;
  const RiftNode({required this.index, required this.type});
}

enum RiftNodeType { combat, elite, altar, boss }
