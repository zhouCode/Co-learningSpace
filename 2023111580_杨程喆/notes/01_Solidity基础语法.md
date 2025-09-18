# Solidity基础语法学习笔记

**学生姓名：** 杨程喆  
**学号：** 2023111580  
**学习日期：** 2024年3月15日 - 2024年6月20日  
**课程：** 区块链技术与智能合约开发  

---

## 🧮 学习目标

作为一名注重算法优化和数据结构的开发者，我的学习重点是：
- 深入理解Solidity中的数据结构实现原理
- 掌握智能合约中的算法优化技巧
- 探索高效的存储和计算模式
- 研究复杂度分析在区块链环境中的应用

---

## 🔍 第一章：数据结构深度解析

### 1.1 高效的映射结构设计

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AdvancedDataStructures
 * @dev 高级数据结构实现与优化
 * @author 杨程喆 (2023111580)
 * @notice 探索Solidity中高效数据结构的设计模式
 */
contract AdvancedDataStructures {
    
    // 双向链表节点结构
    struct DoublyLinkedNode {
        uint256 value;
        uint256 prev;        // 前一个节点ID
        uint256 next;        // 后一个节点ID
        bool exists;         // 节点是否存在
    }
    
    // 双向链表结构
    struct DoublyLinkedList {
        uint256 head;        // 头节点ID
        uint256 tail;        // 尾节点ID
        uint256 size;        // 链表大小
        uint256 nextId;      // 下一个可用ID
        mapping(uint256 => DoublyLinkedNode) nodes;
    }
    
    // 优先队列节点（最小堆实现）
    struct PriorityQueueNode {
        uint256 priority;    // 优先级
        uint256 value;       // 值
        uint256 timestamp;   // 时间戳（用于相同优先级的排序）
    }
    
    // 优先队列结构
    struct PriorityQueue {
        PriorityQueueNode[] heap;
        mapping(uint256 => uint256) valueToIndex; // 值到索引的映射
        uint256 size;
    }
    
    // 布隆过滤器结构
    struct BloomFilter {
        mapping(uint256 => uint256) bitArray;  // 位数组
        uint256 size;                          // 过滤器大小
        uint256 hashCount;                     // 哈希函数数量
        uint256 elementCount;                  // 已添加元素数量
    }
    
    // Trie树节点
    struct TrieNode {
        mapping(bytes1 => uint256) children;  // 子节点映射
        bool isEndOfWord;                     // 是否为单词结尾
        uint256 value;                        // 存储的值
    }
    
    // Trie树结构
    struct Trie {
        mapping(uint256 => TrieNode) nodes;
        uint256 nextNodeId;
        uint256 root;
    }
    
    DoublyLinkedList private _linkedList;
    PriorityQueue private _priorityQueue;
    BloomFilter private _bloomFilter;
    Trie private _trie;
    
    // 事件定义
    event NodeInserted(uint256 indexed nodeId, uint256 value, string operation);
    event NodeRemoved(uint256 indexed nodeId, uint256 value, string operation);
    event PriorityQueueOperation(string operation, uint256 priority, uint256 value);
    event BloomFilterQuery(bytes32 indexed element, bool exists, uint256 falsePositiveRate);
    
    constructor() {
        // 初始化双向链表
        _linkedList.nextId = 1;
        
        // 初始化布隆过滤器（1024位，3个哈希函数）
        _bloomFilter.size = 1024;
        _bloomFilter.hashCount = 3;
        
        // 初始化Trie树
        _trie.nextNodeId = 1;
        _trie.root = 0;
    }
    
    /**
     * @dev 双向链表插入操作 - O(1)时间复杂度
     * @param value 要插入的值
     * @param position 插入位置：0=头部，1=尾部
     * @return nodeId 新节点的ID
     */
    function insertLinkedList(uint256 value, uint8 position) 
        external 
        returns (uint256 nodeId) 
    {
        nodeId = _linkedList.nextId++;
        DoublyLinkedNode storage newNode = _linkedList.nodes[nodeId];
        
        newNode.value = value;
        newNode.exists = true;
        
        if (_linkedList.size == 0) {
            // 第一个节点
            _linkedList.head = nodeId;
            _linkedList.tail = nodeId;
            newNode.prev = 0;
            newNode.next = 0;
        } else if (position == 0) {
            // 插入头部
            DoublyLinkedNode storage oldHead = _linkedList.nodes[_linkedList.head];
            newNode.next = _linkedList.head;
            newNode.prev = 0;
            oldHead.prev = nodeId;
            _linkedList.head = nodeId;
        } else {
            // 插入尾部
            DoublyLinkedNode storage oldTail = _linkedList.nodes[_linkedList.tail];
            newNode.prev = _linkedList.tail;
            newNode.next = 0;
            oldTail.next = nodeId;
            _linkedList.tail = nodeId;
        }
        
        _linkedList.size++;
        
        emit NodeInserted(nodeId, value, "LinkedList Insert");
    }
    
    /**
     * @dev 双向链表删除操作 - O(1)时间复杂度
     * @param nodeId 要删除的节点ID
     */
    function removeLinkedList(uint256 nodeId) external {
        DoublyLinkedNode storage node = _linkedList.nodes[nodeId];
        require(node.exists, "Node does not exist");
        
        uint256 value = node.value;
        
        if (_linkedList.size == 1) {
            // 唯一节点
            _linkedList.head = 0;
            _linkedList.tail = 0;
        } else if (nodeId == _linkedList.head) {
            // 删除头节点
            _linkedList.head = node.next;
            _linkedList.nodes[node.next].prev = 0;
        } else if (nodeId == _linkedList.tail) {
            // 删除尾节点
            _linkedList.tail = node.prev;
            _linkedList.nodes[node.prev].next = 0;
        } else {
            // 删除中间节点
            _linkedList.nodes[node.prev].next = node.next;
            _linkedList.nodes[node.next].prev = node.prev;
        }
        
        delete _linkedList.nodes[nodeId];
        _linkedList.size--;
        
        emit NodeRemoved(nodeId, value, "LinkedList Remove");
    }
    
    /**
     * @dev 优先队列插入 - O(log n)时间复杂度
     * @param priority 优先级（数值越小优先级越高）
     * @param value 值
     */
    function enqueue(uint256 priority, uint256 value) external {
        PriorityQueueNode memory newNode = PriorityQueueNode({
            priority: priority,
            value: value,
            timestamp: block.timestamp
        });
        
        _priorityQueue.heap.push(newNode);
        _priorityQueue.valueToIndex[value] = _priorityQueue.size;
        _priorityQueue.size++;
        
        // 上浮操作
        _heapifyUp(_priorityQueue.size - 1);
        
        emit PriorityQueueOperation("Enqueue", priority, value);
    }
    
    /**
     * @dev 优先队列出队 - O(log n)时间复杂度
     * @return priority 最高优先级
     * @return value 对应的值
     */
    function dequeue() external returns (uint256 priority, uint256 value) {
        require(_priorityQueue.size > 0, "Priority queue is empty");
        
        PriorityQueueNode memory root = _priorityQueue.heap[0];
        priority = root.priority;
        value = root.value;
        
        // 将最后一个元素移到根部
        _priorityQueue.heap[0] = _priorityQueue.heap[_priorityQueue.size - 1];
        _priorityQueue.heap.pop();
        _priorityQueue.size--;
        
        if (_priorityQueue.size > 0) {
            // 下沉操作
            _heapifyDown(0);
        }
        
        delete _priorityQueue.valueToIndex[value];
        
        emit PriorityQueueOperation("Dequeue", priority, value);
    }
    
    /**
     * @dev 堆上浮操作
     * @param index 当前索引
     */
    function _heapifyUp(uint256 index) internal {
        while (index > 0) {
            uint256 parentIndex = (index - 1) / 2;
            
            if (_compareNodes(_priorityQueue.heap[index], _priorityQueue.heap[parentIndex])) {
                // 交换节点
                PriorityQueueNode memory temp = _priorityQueue.heap[index];
                _priorityQueue.heap[index] = _priorityQueue.heap[parentIndex];
                _priorityQueue.heap[parentIndex] = temp;
                
                // 更新索引映射
                _priorityQueue.valueToIndex[_priorityQueue.heap[index].value] = index;
                _priorityQueue.valueToIndex[_priorityQueue.heap[parentIndex].value] = parentIndex;
                
                index = parentIndex;
            } else {
                break;
            }
        }
    }
    
    /**
     * @dev 堆下沉操作
     * @param index 当前索引
     */
    function _heapifyDown(uint256 index) internal {
        while (true) {
            uint256 leftChild = 2 * index + 1;
            uint256 rightChild = 2 * index + 2;
            uint256 smallest = index;
            
            if (leftChild < _priorityQueue.size && 
                _compareNodes(_priorityQueue.heap[leftChild], _priorityQueue.heap[smallest])) {
                smallest = leftChild;
            }
            
            if (rightChild < _priorityQueue.size && 
                _compareNodes(_priorityQueue.heap[rightChild], _priorityQueue.heap[smallest])) {
                smallest = rightChild;
            }
            
            if (smallest != index) {
                // 交换节点
                PriorityQueueNode memory temp = _priorityQueue.heap[index];
                _priorityQueue.heap[index] = _priorityQueue.heap[smallest];
                _priorityQueue.heap[smallest] = temp;
                
                // 更新索引映射
                _priorityQueue.valueToIndex[_priorityQueue.heap[index].value] = index;
                _priorityQueue.valueToIndex[_priorityQueue.heap[smallest].value] = smallest;
                
                index = smallest;
            } else {
                break;
            }
        }
    }
    
    /**
     * @dev 比较两个优先队列节点
     * @param a 节点A
     * @param b 节点B
     * @return 如果A的优先级高于B返回true
     */
    function _compareNodes(PriorityQueueNode memory a, PriorityQueueNode memory b) 
        internal 
        pure 
        returns (bool) 
    {
        if (a.priority != b.priority) {
            return a.priority < b.priority; // 数值越小优先级越高
        }
        return a.timestamp < b.timestamp; // 相同优先级时，时间戳越小优先级越高
    }
    
    /**
     * @dev 布隆过滤器添加元素 - O(k)时间复杂度，k为哈希函数数量
     * @param element 要添加的元素
     */
    function bloomFilterAdd(bytes32 element) external {
        for (uint256 i = 0; i < _bloomFilter.hashCount; i++) {
            uint256 hash = _hash(element, i) % _bloomFilter.size;
            uint256 wordIndex = hash / 256;
            uint256 bitIndex = hash % 256;
            _bloomFilter.bitArray[wordIndex] |= (1 << bitIndex);
        }
        _bloomFilter.elementCount++;
    }
    
    /**
     * @dev 布隆过滤器查询元素 - O(k)时间复杂度
     * @param element 要查询的元素
     * @return exists 可能存在（true）或确定不存在（false）
     * @return falsePositiveRate 当前假阳性率（估算）
     */
    function bloomFilterQuery(bytes32 element) 
        external 
        returns (bool exists, uint256 falsePositiveRate) 
    {
        exists = true;
        
        for (uint256 i = 0; i < _bloomFilter.hashCount; i++) {
            uint256 hash = _hash(element, i) % _bloomFilter.size;
            uint256 wordIndex = hash / 256;
            uint256 bitIndex = hash % 256;
            
            if ((_bloomFilter.bitArray[wordIndex] & (1 << bitIndex)) == 0) {
                exists = false;
                break;
            }
        }
        
        // 估算假阳性率：(1 - e^(-kn/m))^k
        // 简化计算：使用近似公式
        if (_bloomFilter.elementCount > 0) {
            uint256 ratio = (_bloomFilter.hashCount * _bloomFilter.elementCount * 1000) / _bloomFilter.size;
            falsePositiveRate = ratio > 1000 ? 500 : (ratio * ratio) / 2000; // 简化的假阳性率估算
        }
        
        emit BloomFilterQuery(element, exists, falsePositiveRate);
    }
    
    /**
     * @dev Trie树插入 - O(m)时间复杂度，m为键的长度
     * @param key 键
     * @param value 值
     */
    function trieInsert(bytes memory key, uint256 value) external {
        uint256 currentNode = _trie.root;
        
        // 如果根节点不存在，创建它
        if (currentNode == 0) {
            currentNode = _trie.nextNodeId++;
            _trie.root = currentNode;
        }
        
        for (uint256 i = 0; i < key.length; i++) {
            bytes1 char = key[i];
            uint256 childNode = _trie.nodes[currentNode].children[char];
            
            if (childNode == 0) {
                // 创建新的子节点
                childNode = _trie.nextNodeId++;
                _trie.nodes[currentNode].children[char] = childNode;
            }
            
            currentNode = childNode;
        }
        
        _trie.nodes[currentNode].isEndOfWord = true;
        _trie.nodes[currentNode].value = value;
    }
    
    /**
     * @dev Trie树查询 - O(m)时间复杂度
     * @param key 键
     * @return exists 是否存在
     * @return value 对应的值
     */
    function trieQuery(bytes memory key) 
        external 
        view 
        returns (bool exists, uint256 value) 
    {
        uint256 currentNode = _trie.root;
        
        if (currentNode == 0) {
            return (false, 0);
        }
        
        for (uint256 i = 0; i < key.length; i++) {
            bytes1 char = key[i];
            currentNode = _trie.nodes[currentNode].children[char];
            
            if (currentNode == 0) {
                return (false, 0);
            }
        }
        
        exists = _trie.nodes[currentNode].isEndOfWord;
        value = _trie.nodes[currentNode].value;
    }
    
    /**
     * @dev 哈希函数（用于布隆过滤器）
     * @param data 数据
     * @param seed 种子
     * @return 哈希值
     */
    function _hash(bytes32 data, uint256 seed) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(data, seed)));
    }
    
    // 查询函数
    function getLinkedListSize() external view returns (uint256) {
        return _linkedList.size;
    }
    
    function getPriorityQueueSize() external view returns (uint256) {
        return _priorityQueue.size;
    }
    
    function getBloomFilterStats() external view returns (uint256 size, uint256 elementCount) {
        return (_bloomFilter.size, _bloomFilter.elementCount);
    }
    
    // 个人心得：数据结构的选择直接影响算法效率
    // 在区块链环境中，Gas成本让我们更加重视算法复杂度
}
```

### 1.2 高效排序算法实现

```solidity
contract OptimizedSorting {
    
    // 排序结果结构
    struct SortResult {
        uint256[] sortedArray;
        uint256 comparisons;     // 比较次数
        uint256 swaps;          // 交换次数
        uint256 gasUsed;        // 消耗的Gas
        string algorithm;       // 使用的算法
    }
    
    event SortCompleted(
        string algorithm,
        uint256 arrayLength,
        uint256 comparisons,
        uint256 swaps,
        uint256 gasUsed
    );
    
    /**
     * @dev 快速排序实现 - 平均O(n log n)，最坏O(n²)
     * @param arr 待排序数组
     * @return result 排序结果
     */
    function quickSort(uint256[] memory arr) 
        external 
        returns (SortResult memory result) 
    {
        uint256 gasStart = gasleft();
        uint256 comparisons = 0;
        uint256 swaps = 0;
        
        if (arr.length <= 1) {
            return SortResult({
                sortedArray: arr,
                comparisons: 0,
                swaps: 0,
                gasUsed: gasStart - gasleft(),
                algorithm: "QuickSort"
            });
        }
        
        _quickSortRecursive(arr, 0, int256(arr.length - 1), comparisons, swaps);
        
        uint256 gasUsed = gasStart - gasleft();
        
        result = SortResult({
            sortedArray: arr,
            comparisons: comparisons,
            swaps: swaps,
            gasUsed: gasUsed,
            algorithm: "QuickSort"
        });
        
        emit SortCompleted("QuickSort", arr.length, comparisons, swaps, gasUsed);
    }
    
    /**
     * @dev 快速排序递归实现
     */
    function _quickSortRecursive(
        uint256[] memory arr,
        int256 low,
        int256 high,
        uint256 comparisons,
        uint256 swaps
    ) internal {
        if (low < high) {
            int256 pivotIndex = _partition(arr, low, high, comparisons, swaps);
            _quickSortRecursive(arr, low, pivotIndex - 1, comparisons, swaps);
            _quickSortRecursive(arr, pivotIndex + 1, high, comparisons, swaps);
        }
    }
    
    /**
     * @dev 分区函数
     */
    function _partition(
        uint256[] memory arr,
        int256 low,
        int256 high,
        uint256 comparisons,
        uint256 swaps
    ) internal returns (int256) {
        uint256 pivot = arr[uint256(high)];
        int256 i = low - 1;
        
        for (int256 j = low; j < high; j++) {
            comparisons++;
            if (arr[uint256(j)] <= pivot) {
                i++;
                if (i != j) {
                    _swap(arr, uint256(i), uint256(j));
                    swaps++;
                }
            }
        }
        
        if (i + 1 != high) {
            _swap(arr, uint256(i + 1), uint256(high));
            swaps++;
        }
        
        return i + 1;
    }
    
    /**
     * @dev 归并排序实现 - O(n log n)稳定排序
     * @param arr 待排序数组
     * @return result 排序结果
     */
    function mergeSort(uint256[] memory arr) 
        external 
        returns (SortResult memory result) 
    {
        uint256 gasStart = gasleft();
        uint256 comparisons = 0;
        
        if (arr.length <= 1) {
            return SortResult({
                sortedArray: arr,
                comparisons: 0,
                swaps: 0,
                gasUsed: gasStart - gasleft(),
                algorithm: "MergeSort"
            });
        }
        
        uint256[] memory temp = new uint256[](arr.length);
        _mergeSortRecursive(arr, temp, 0, arr.length - 1, comparisons);
        
        uint256 gasUsed = gasStart - gasleft();
        
        result = SortResult({
            sortedArray: arr,
            comparisons: comparisons,
            swaps: 0, // 归并排序不涉及交换，而是复制
            gasUsed: gasUsed,
            algorithm: "MergeSort"
        });
        
        emit SortCompleted("MergeSort", arr.length, comparisons, 0, gasUsed);
    }
    
    /**
     * @dev 归并排序递归实现
     */
    function _mergeSortRecursive(
        uint256[] memory arr,
        uint256[] memory temp,
        uint256 left,
        uint256 right,
        uint256 comparisons
    ) internal {
        if (left < right) {
            uint256 mid = left + (right - left) / 2;
            
            _mergeSortRecursive(arr, temp, left, mid, comparisons);
            _mergeSortRecursive(arr, temp, mid + 1, right, comparisons);
            _merge(arr, temp, left, mid, right, comparisons);
        }
    }
    
    /**
     * @dev 合并函数
     */
    function _merge(
        uint256[] memory arr,
        uint256[] memory temp,
        uint256 left,
        uint256 mid,
        uint256 right,
        uint256 comparisons
    ) internal {
        // 复制到临时数组
        for (uint256 i = left; i <= right; i++) {
            temp[i] = arr[i];
        }
        
        uint256 i = left;
        uint256 j = mid + 1;
        uint256 k = left;
        
        // 合并两个有序数组
        while (i <= mid && j <= right) {
            comparisons++;
            if (temp[i] <= temp[j]) {
                arr[k] = temp[i];
                i++;
            } else {
                arr[k] = temp[j];
                j++;
            }
            k++;
        }
        
        // 复制剩余元素
        while (i <= mid) {
            arr[k] = temp[i];
            i++;
            k++;
        }
        
        while (j <= right) {
            arr[k] = temp[j];
            j++;
            k++;
        }
    }
    
    /**
     * @dev 堆排序实现 - O(n log n)原地排序
     * @param arr 待排序数组
     * @return result 排序结果
     */
    function heapSort(uint256[] memory arr) 
        external 
        returns (SortResult memory result) 
    {
        uint256 gasStart = gasleft();
        uint256 comparisons = 0;
        uint256 swaps = 0;
        
        if (arr.length <= 1) {
            return SortResult({
                sortedArray: arr,
                comparisons: 0,
                swaps: 0,
                gasUsed: gasStart - gasleft(),
                algorithm: "HeapSort"
            });
        }
        
        // 构建最大堆
        for (int256 i = int256(arr.length / 2) - 1; i >= 0; i--) {
            _heapify(arr, arr.length, uint256(i), comparisons, swaps);
        }
        
        // 逐个提取元素
        for (uint256 i = arr.length - 1; i > 0; i--) {
            _swap(arr, 0, i);
            swaps++;
            _heapify(arr, i, 0, comparisons, swaps);
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        result = SortResult({
            sortedArray: arr,
            comparisons: comparisons,
            swaps: swaps,
            gasUsed: gasUsed,
            algorithm: "HeapSort"
        });
        
        emit SortCompleted("HeapSort", arr.length, comparisons, swaps, gasUsed);
    }
    
    /**
     * @dev 堆化操作
     */
    function _heapify(
        uint256[] memory arr,
        uint256 n,
        uint256 i,
        uint256 comparisons,
        uint256 swaps
    ) internal {
        uint256 largest = i;
        uint256 left = 2 * i + 1;
        uint256 right = 2 * i + 2;
        
        if (left < n) {
            comparisons++;
            if (arr[left] > arr[largest]) {
                largest = left;
            }
        }
        
        if (right < n) {
            comparisons++;
            if (arr[right] > arr[largest]) {
                largest = right;
            }
        }
        
        if (largest != i) {
            _swap(arr, i, largest);
            swaps++;
            _heapify(arr, n, largest, comparisons, swaps);
        }
    }
    
    /**
     * @dev 计数排序实现 - O(n + k)线性时间排序
     * @param arr 待排序数组
     * @param maxValue 数组中的最大值
     * @return result 排序结果
     */
    function countingSort(uint256[] memory arr, uint256 maxValue) 
        external 
        returns (SortResult memory result) 
    {
        uint256 gasStart = gasleft();
        
        if (arr.length <= 1) {
            return SortResult({
                sortedArray: arr,
                comparisons: 0,
                swaps: 0,
                gasUsed: gasStart - gasleft(),
                algorithm: "CountingSort"
            });
        }
        
        // 创建计数数组
        uint256[] memory count = new uint256[](maxValue + 1);
        
        // 计数
        for (uint256 i = 0; i < arr.length; i++) {
            count[arr[i]]++;
        }
        
        // 累积计数
        for (uint256 i = 1; i <= maxValue; i++) {
            count[i] += count[i - 1];
        }
        
        // 构建输出数组
        uint256[] memory output = new uint256[](arr.length);
        for (int256 i = int256(arr.length) - 1; i >= 0; i--) {
            uint256 value = arr[uint256(i)];
            output[count[value] - 1] = value;
            count[value]--;
        }
        
        // 复制回原数组
        for (uint256 i = 0; i < arr.length; i++) {
            arr[i] = output[i];
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        result = SortResult({
            sortedArray: arr,
            comparisons: 0, // 计数排序不需要比较
            swaps: 0,
            gasUsed: gasUsed,
            algorithm: "CountingSort"
        });
        
        emit SortCompleted("CountingSort", arr.length, 0, 0, gasUsed);
    }
    
    /**
     * @dev 基数排序实现 - O(d * (n + k))线性时间排序
     * @param arr 待排序数组
     * @return result 排序结果
     */
    function radixSort(uint256[] memory arr) 
        external 
        returns (SortResult memory result) 
    {
        uint256 gasStart = gasleft();
        
        if (arr.length <= 1) {
            return SortResult({
                sortedArray: arr,
                comparisons: 0,
                swaps: 0,
                gasUsed: gasStart - gasleft(),
                algorithm: "RadixSort"
            });
        }
        
        // 找到最大值以确定位数
        uint256 maxValue = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] > maxValue) {
                maxValue = arr[i];
            }
        }
        
        // 对每一位进行计数排序
        for (uint256 exp = 1; maxValue / exp > 0; exp *= 10) {
            _countingSortByDigit(arr, exp);
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        result = SortResult({
            sortedArray: arr,
            comparisons: 0,
            swaps: 0,
            gasUsed: gasUsed,
            algorithm: "RadixSort"
        });
        
        emit SortCompleted("RadixSort", arr.length, 0, 0, gasUsed);
    }
    
    /**
     * @dev 按指定位进行计数排序
     */
    function _countingSortByDigit(uint256[] memory arr, uint256 exp) internal {
        uint256[] memory output = new uint256[](arr.length);
        uint256[] memory count = new uint256[](10); // 0-9的计数
        
        // 计数
        for (uint256 i = 0; i < arr.length; i++) {
            count[(arr[i] / exp) % 10]++;
        }
        
        // 累积计数
        for (uint256 i = 1; i < 10; i++) {
            count[i] += count[i - 1];
        }
        
        // 构建输出数组
        for (int256 i = int256(arr.length) - 1; i >= 0; i--) {
            uint256 digit = (arr[uint256(i)] / exp) % 10;
            output[count[digit] - 1] = arr[uint256(i)];
            count[digit]--;
        }
        
        // 复制回原数组
        for (uint256 i = 0; i < arr.length; i++) {
            arr[i] = output[i];
        }
    }
    
    /**
     * @dev 交换数组中的两个元素
     */
    function _swap(uint256[] memory arr, uint256 i, uint256 j) internal pure {
        uint256 temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
    }
    
    /**
     * @dev 算法性能比较
     * @param arr 测试数组
     * @return results 各算法的性能结果
     */
    function compareAlgorithms(uint256[] memory arr) 
        external 
        returns (SortResult[] memory results) 
    {
        results = new SortResult[](3);
        
        // 测试快速排序
        uint256[] memory arr1 = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            arr1[i] = arr[i];
        }
        results[0] = this.quickSort(arr1);
        
        // 测试归并排序
        uint256[] memory arr2 = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            arr2[i] = arr[i];
        }
        results[1] = this.mergeSort(arr2);
        
        // 测试堆排序
        uint256[] memory arr3 = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            arr3[i] = arr[i];
        }
        results[2] = this.heapSort(arr3);
    }
    
    // 个人心得：不同的排序算法在不同场景下有不同的优势
    // 在区块链环境中，Gas效率往往比时间复杂度更重要
}
```

---

## 🔬 第二章：算法复杂度分析与优化

### 2.1 时间复杂度优化技巧

```solidity
contract ComplexityOptimization {
    
    // 缓存结构
    struct Cache {
        mapping(bytes32 => uint256) results;
        mapping(bytes32 => bool) exists;
        uint256 hitCount;
        uint256 missCount;
    }
    
    // 分段处理配置
    struct BatchConfig {
        uint256 batchSize;       // 批处理大小
        uint256 maxGasPerBatch;  // 每批最大Gas
        uint256 currentBatch;    // 当前批次
        uint256 totalBatches;    // 总批次数
    }
    
    Cache private _fibonacciCache;
    Cache private _factorialCache;
    mapping(uint256 => BatchConfig) private _batchConfigs;
    
    event ComplexityAnalysis(
        string operation,
        uint256 inputSize,
        uint256 gasUsed,
        uint256 timeComplexity,
        string optimizationApplied
    );
    
    event CacheHit(string operation, bytes32 key, uint256 result);
    event CacheMiss(string operation, bytes32 key);
    
    /**
     * @dev 优化的斐波那契数列计算 - 从O(2^n)优化到O(n)
     * @param n 第n项
     * @return result 斐波那契数
     */
    function optimizedFibonacci(uint256 n) external returns (uint256 result) {
        uint256 gasStart = gasleft();
        
        bytes32 key = keccak256(abi.encodePacked("fibonacci", n));
        
        // 检查缓存
        if (_fibonacciCache.exists[key]) {
            _fibonacciCache.hitCount++;
            result = _fibonacciCache.results[key];
            emit CacheHit("Fibonacci", key, result);
            return result;
        }
        
        _fibonacciCache.missCount++;
        emit CacheMiss("Fibonacci", key);
        
        if (n <= 1) {
            result = n;
        } else {
            // 使用动态规划，避免重复计算
            uint256 prev = 0;
            uint256 curr = 1;
            
            for (uint256 i = 2; i <= n; i++) {
                uint256 temp = curr;
                curr = prev + curr;
                prev = temp;
                
                // 缓存中间结果
                bytes32 intermediateKey = keccak256(abi.encodePacked("fibonacci", i));
                _fibonacciCache.results[intermediateKey] = curr;
                _fibonacciCache.exists[intermediateKey] = true;
            }
            
            result = curr;
        }
        
        // 缓存最终结果
        _fibonacciCache.results[key] = result;
        _fibonacciCache.exists[key] = true;
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexityAnalysis(
            "Fibonacci",
            n,
            gasUsed,
            n, // O(n)时间复杂度
            "Dynamic Programming + Memoization"
        );
    }
    
    /**
     * @dev 优化的阶乘计算 - 使用缓存和增量计算
     * @param n 计算n!
     * @return result 阶乘结果
     */
    function optimizedFactorial(uint256 n) external returns (uint256 result) {
        uint256 gasStart = gasleft();
        
        bytes32 key = keccak256(abi.encodePacked("factorial", n));
        
        // 检查缓存
        if (_factorialCache.exists[key]) {
            _factorialCache.hitCount++;
            result = _factorialCache.results[key];
            emit CacheHit("Factorial", key, result);
            return result;
        }
        
        _factorialCache.missCount++;
        emit CacheMiss("Factorial", key);
        
        if (n == 0 || n == 1) {
            result = 1;
        } else {
            // 寻找最大的已缓存值
            uint256 startFrom = 1;
            uint256 startValue = 1;
            
            for (uint256 i = n - 1; i > 1; i--) {
                bytes32 checkKey = keccak256(abi.encodePacked("factorial", i));
                if (_factorialCache.exists[checkKey]) {
                    startFrom = i;
                    startValue = _factorialCache.results[checkKey];
                    break;
                }
            }
            
            // 从已知值开始计算
            result = startValue;
            for (uint256 i = startFrom + 1; i <= n; i++) {
                result *= i;
                
                // 缓存中间结果
                bytes32 intermediateKey = keccak256(abi.encodePacked("factorial", i));
                _factorialCache.results[intermediateKey] = result;
                _factorialCache.exists[intermediateKey] = true;
            }
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexityAnalysis(
            "Factorial",
            n,
            gasUsed,
            n - startFrom, // 实际计算的步数
            "Incremental Calculation + Memoization"
        );
    }
    
    /**
     * @dev 优化的数组查找 - 使用二分查找
     * @param sortedArray 已排序数组
     * @param target 目标值
     * @return found 是否找到
     * @return index 索引位置
     */
    function optimizedBinarySearch(
        uint256[] memory sortedArray,
        uint256 target
    ) external returns (bool found, uint256 index) {
        uint256 gasStart = gasleft();
        uint256 comparisons = 0;
        
        uint256 left = 0;
        uint256 right = sortedArray.length;
        
        while (left < right) {
            uint256 mid = left + (right - left) / 2;
            comparisons++;
            
            if (sortedArray[mid] == target) {
                found = true;
                index = mid;
                break;
            } else if (sortedArray[mid] < target) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexityAnalysis(
            "Binary Search",
            sortedArray.length,
            gasUsed,
            comparisons, // 实际比较次数，理论上是O(log n)
            "Binary Search Algorithm"
        );
    }
    
    /**
     * @dev 批处理优化 - 将大任务分解为小批次
     * @param data 待处理数据
     * @param batchId 批处理ID
     * @return completed 是否完成
     * @return nextBatch 下一批次索引
     */
    function batchProcess(
        uint256[] memory data,
        uint256 batchId
    ) external returns (bool completed, uint256 nextBatch) {
        uint256 gasStart = gasleft();
        
        BatchConfig storage config = _batchConfigs[batchId];
        
        // 初始化批处理配置
        if (config.batchSize == 0) {
            config.batchSize = 50; // 默认批大小
            config.maxGasPerBatch = 200000; // 最大Gas限制
            config.totalBatches = (data.length + config.batchSize - 1) / config.batchSize;
        }
        
        uint256 startIndex = config.currentBatch * config.batchSize;
        uint256 endIndex = startIndex + config.batchSize;
        
        if (endIndex > data.length) {
            endIndex = data.length;
        }
        
        // 处理当前批次
        uint256 processedCount = 0;
        for (uint256 i = startIndex; i < endIndex; i++) {
            // 检查Gas限制
            if (gasStart - gasleft() > config.maxGasPerBatch) {
                break;
            }
            
            // 模拟复杂处理
            _complexProcessing(data[i]);
            processedCount++;
        }
        
        config.currentBatch++;
        completed = config.currentBatch >= config.totalBatches;
        nextBatch = config.currentBatch;
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexityAnalysis(
            "Batch Processing",
            processedCount,
            gasUsed,
            processedCount, // O(n)但分批执行
            "Batch Processing Optimization"
        );
    }
    
    /**
     * @dev 模拟复杂处理
     */
    function _complexProcessing(uint256 value) internal pure {
        // 模拟一些复杂计算
        uint256 result = value;
        for (uint256 i = 0; i < 10; i++) {
            result = (result * 31 + 17) % 1000000007;
        }
    }
    
    /**
     * @dev 空间复杂度优化 - 原地算法
     * @param arr 数组
     * @return 反转后的数组
     */
    function inPlaceReverse(uint256[] memory arr) 
        external 
        returns (uint256[] memory) 
    {
        uint256 gasStart = gasleft();
        
        uint256 left = 0;
        uint256 right = arr.length - 1;
        uint256 swaps = 0;
        
        while (left < right) {
            // 原地交换，不使用额外空间
            uint256 temp = arr[left];
            arr[left] = arr[right];
            arr[right] = temp;
            
            left++;
            right--;
            swaps++;
        }
        
        uint256 gasUsed = gasStart - gasleft();
        
        emit ComplexityAnalysis(
            "In-Place Reverse",
            arr.length,
            gasUsed,
            swaps, // O(n/2)
            "In-Place Algorithm (O(1) space)"
        );
        
        return arr;
    }
    
    /**
     * @dev 获取缓存统计
     * @param cacheType 缓存类型
     * @return hitCount 命中次数
     * @return missCount 未命中次数
     * @return hitRate 命中率
     */
    function getCacheStats(string memory cacheType) 
        external 
        view 
        returns (uint256 hitCount, uint256 missCount, uint256 hitRate) 
    {
        Cache storage cache;
        
        if (keccak256(bytes(cacheType)) == keccak256(bytes("fibonacci"))) {
            cache = _fibonacciCache;
        } else if (keccak256(bytes(cacheType)) == keccak256(bytes("factorial"))) {
            cache = _factorialCache;
        }
        
        hitCount = cache.hitCount;
        missCount = cache.missCount;
        
        uint256 totalAccess = hitCount + missCount;
        hitRate = totalAccess > 0 ? (hitCount * 100) / totalAccess : 0;
    }
    
    /**
     * @dev 清除缓存
     * @param cacheType 缓存类型
     */
    function clearCache(string memory cacheType) external {
        if (keccak256(bytes(cacheType)) == keccak256(bytes("fibonacci"))) {
            _fibonacciCache.hitCount = 0;
            _fibonacciCache.missCount = 0;
        } else if (keccak256(bytes(cacheType)) == keccak256(bytes("factorial"))) {
            _factorialCache.hitCount = 0;
            _factorialCache.missCount = 0;
        }
    }
    
    // 个人心得：算法优化不仅要考虑时间复杂度，还要考虑空间复杂度和Gas成本
    // 缓存和批处理是区块链环境中常用的优化技巧
}
```

### 2.2 空间复杂度优化

```solidity
contract SpaceOptimization {
    
    // 压缩存储结构
    struct PackedData {
        uint128 value1;      // 使用更小的数据类型
        uint64 value2;
        uint32 value3;
        uint16 value4;
        uint8 value5;
        bool flag1;
        bool flag2;
        // 总共256位，正好一个存储槽
    }
    
    // 位操作优化的集合
    struct BitSet {
        mapping(uint256 => uint256) bits;
        uint256 size;
    }
    
    // 稀疏数组优化
    struct SparseArray {
        mapping(uint256 => uint256) data;
        mapping(uint256 => bool) exists;
        uint256[] indices;
        uint256 count;
    }
    
    PackedData[] private _packedArray;
    BitSet private _bitSet;
    SparseArray private _sparseArray;
    
    event SpaceOptimization(
        string operation,
        uint256 originalSize,
        uint256 optimizedSize,
        uint256 spaceSaved,
        string technique
    );
    
    /**
     * @dev 位集合操作 - 节省存储空间
     * @param element 元素值
     */
    function addToBitSet(uint256 element) external {
        uint256 wordIndex = element / 256;
        uint256 bitIndex = element % 256;
        
        uint256 originalSize = _bitSet.size;
        
        // 设置对应位
        _bitSet.bits[wordIndex] |= (1 << bitIndex);
        
        // 更新大小
        if (element >= _bitSet.size) {
            _bitSet.size = element + 1;
        }
        
        uint256 optimizedSize = (_bitSet.size + 255) / 256; // 实际使用的字数
        uint256 spaceSaved = _bitSet.size - optimizedSize;
        
        emit SpaceOptimization(
            "BitSet Add",
            _bitSet.size,
            optimizedSize,
            spaceSaved,
            "Bit Manipulation"
        );
    }
    
    /**
     * @dev 检查位集合中是否存在元素
     * @param element 元素值
     * @return exists 是否存在
     */
    function existsInBitSet(uint256 element) external view returns (bool exists) {
        if (element >= _bitSet.size) {
            return false;
        }
        
        uint256 wordIndex = element / 256;
        uint256 bitIndex = element % 256;
        
        return (_bitSet.bits[wordIndex] & (1 << bitIndex)) != 0;
    }
    
    /**
     * @dev 稀疏数组操作 - 只存储非零值
     * @param index 索引
     * @param value 值
     */
    function setSparseArrayValue(uint256 index, uint256 value) external {
        uint256 originalCount = _sparseArray.count;
        
        if (value == 0) {
            // 删除元素
            if (_sparseArray.exists[index]) {
                delete _sparseArray.data[index];
                _sparseArray.exists[index] = false;
                
                // 从索引数组中移除
                for (uint256 i = 0; i < _sparseArray.indices.length; i++) {
                    if (_sparseArray.indices[i] == index) {
                        _sparseArray.indices[i] = _sparseArray.indices[_sparseArray.indices.length - 1];
                        _sparseArray.indices.pop();
                        break;
                    }
                }
                _sparseArray.count--;
            }
        } else {
            // 添加或更新元素
            if (!_sparseArray.exists[index]) {
                _sparseArray.indices.push(index);
                _sparseArray.count++;
            }
            
            _sparseArray.data[index] = value;
            _sparseArray.exists[index] = true;
        }
        
        // 计算空间节省
        uint256 denseArraySize = index + 1; // 如果使用密集数组需要的大小
        uint256 sparseArraySize = _sparseArray.count;
        uint256 spaceSaved = denseArraySize > sparseArraySize ? 
                            denseArraySize - sparseArraySize : 0;
        
        emit SpaceOptimization(
            "Sparse Array",
            denseArraySize,
            sparseArraySize,
            spaceSaved,
            "Sparse Data Structure"
        );
    }
    
    /**
     * @dev 获取稀疏数组值
     * @param index 索引
     * @return value 值
     */
    function getSparseArrayValue(uint256 index) external view returns (uint256 value) {
        return _sparseArray.exists[index] ? _sparseArray.data[index] : 0;
    }
    
    /**
     * @dev 数据打包优化
     * @param values 要打包的值数组
     */
    function packData(
        uint128 value1,
        uint64 value2,
        uint32 value3,
        uint16 value4,
        uint8 value5,
        bool flag1,
        bool flag2
    ) external {
        uint256 originalSize = 5; // 如果每个值都用uint256存储
        
        PackedData memory packed = PackedData({
            value1: value1,
            value2: value2,
            value3: value3,
            value4: value4,
            value5: value5,
            flag1: flag1,
            flag2: flag2
        });
        
        _packedArray.push(packed);
        
        uint256 optimizedSize = 1; // 打包后只需要1个存储槽
        uint256 spaceSaved = originalSize - optimizedSize;
        
        emit SpaceOptimization(
            "Data Packing",
            originalSize,
            optimizedSize,
            spaceSaved,
            "Struct Packing"
        );
    }
    
    /**
     * @dev 字符串压缩存储
     * @param longString 长字符串
     * @return compressedHash 压缩后的哈希
     */
    function compressString(string memory longString) 
        external 
        pure 
        returns (bytes32 compressedHash) 
    {
        // 使用哈希来压缩长字符串
        compressedHash = keccak256(bytes(longString));
        
        // 注意：这种压缩是有损的，只适用于不需要恢复原始数据的场景
        // 在实际应用中，可以结合链下存储来实现无损压缩
    }
    
    /**
     * @dev 动态数组优化 - 预分配和批量操作
     * @param elements 要添加的元素
     */
    function optimizedBatchAdd(uint256[] memory elements) external {
        uint256 originalLength = _packedArray.length;
        
        // 预分配空间（在Solidity中通过循环实现）
        for (uint256 i = 0; i < elements.length; i++) {
            PackedData memory newData = PackedData({
                value1: uint128(elements[i]),
                value2: uint64(elements[i] >> 128),
                value3: uint32(elements[i] >> 192),
                value4: uint16(elements[i] >> 224),
                value5: uint8(elements[i] >> 240),
                flag1: (elements[i] & 1) == 1,
                flag2: (elements[i] & 2) == 2
            });
            
            _packedArray.push(newData);
        }
        
        uint256 newLength = _packedArray.length;
        
        emit SpaceOptimization(
            "Batch Add",
            elements.length,
            newLength - originalLength,
            0, // 批量操作主要优化时间而非空间
            "Batch Operations"
        );
    }
    
    /**
     * @dev 内存池优化 - 重用已删除的槽位
     * @param index 要删除的索引
     */
    function optimizedDelete(uint256 index) external {
        require(index < _packedArray.length, "Index out of bounds");
        
        uint256 originalLength = _packedArray.length;
        
        // 将最后一个元素移到要删除的位置
        if (index < _packedArray.length - 1) {
            _packedArray[index] = _packedArray[_packedArray.length - 1];
        }
        
        _packedArray.pop();
        
        uint256 newLength = _packedArray.length;
        
        emit SpaceOptimization(
            "Optimized Delete",
            originalLength,
            newLength,
            1, // 节省一个存储槽
            "Swap and Pop"
        );
    }
    
    /**
     * @dev 获取存储统计信息
     * @return packedArraySize 打包数组大小
     * @return bitSetSize 位集合大小
     * @return sparseArraySize 稀疏数组大小
     */
    function getStorageStats() 
        external 
        view 
        returns (
            uint256 packedArraySize,
            uint256 bitSetSize,
            uint256 sparseArraySize
        ) 
    {
        packedArraySize = _packedArray.length;
        bitSetSize = (_bitSet.size + 255) / 256; // 实际使用的字数
        sparseArraySize = _sparseArray.count;
    }
    
    // 个人心得：空间优化在区块链中尤为重要，每个存储槽都有成本
    // 位操作、数据打包、稀疏结构都是有效的优化手段
}
```

---

## 🎯 第三章：高级算法实现

### 3.1 图算法实现

```solidity
contract GraphAlgorithms {
    
    // 图的边结构
    struct Edge {
        uint256 from;
        uint256 to;
        uint256 weight;
        bool exists;
    }
    
    // 图结构
    struct Graph {
        mapping(uint256 => mapping(uint256 => Edge)) edges;
        mapping(uint256 => uint256[]) adjacencyList;
        mapping(uint256 => bool) vertices;
        uint256 vertexCount;
        uint256 edgeCount;
        bool isDirected;
    }
    
    // 最短路径结果
    struct ShortestPathResult {
        uint256[] path;
        uint256 distance;
        bool pathExists;
    }
    
    Graph private _graph;
    
    event GraphOperation(
        string operation,
        uint256 vertex1,
        uint256 vertex2,
        uint256 weight,
        string algorithm
    );
    
    event PathFound(
        uint256 source,
        uint256 destination,
        uint256[] path,
        uint256 distance,
        string algorithm
    );
    
    constructor(bool isDirected) {
        _graph.isDirected = isDirected;
    }
    
    /**
     * @dev 添加边
     * @param from 起始顶点
     * @param to 目标顶点
     * @param weight 权重
     */
    function addEdge(uint256 from, uint256 to, uint256 weight) external {
        // 添加顶点
        if (!_graph.vertices[from]) {
            _graph.vertices[from] = true;
            _graph.vertexCount++;
        }
        
        if (!_graph.vertices[to]) {
            _graph.vertices[to] = true;
            _graph.vertexCount++;
        }
        
        // 添加边
        if (!_graph.edges[from][to].exists) {
            _graph.edges[from][to] = Edge(from, to, weight, true);
            _graph.adjacencyList[from].push(to);
            _graph.edgeCount++;
            
            // 无向图需要添加反向边
            if (!_graph.isDirected && from != to) {
                _graph.edges[to][from] = Edge(to, from, weight, true);
                _graph.adjacencyList[to].push(from);
            }
        } else {
            // 更新权重
            _graph.edges[from][to].weight = weight;
            if (!_graph.isDirected) {
                _graph.edges[to][from].weight = weight;
            }
        }
        
        emit GraphOperation("Add Edge", from, to, weight, "Graph Construction");
    }
    
    /**
     * @dev Dijkstra最短路径算法 - O((V + E) log V)
     * @param source 源顶点
     * @param destination 目标顶点
     * @return result 最短路径结果
     */
    function dijkstraShortestPath(uint256 source, uint256 destination)
        external
        returns (ShortestPathResult memory result)
    {
        require(_graph.vertices[source], "Source vertex does not exist");
        require(_graph.vertices[destination], "Destination vertex does not exist");
        
        // 距离数组
        mapping(uint256 => uint256) storage distances;
        mapping(uint256 => uint256) storage previous;
        mapping(uint256 => bool) storage visited;
        
        // 初始化
        uint256[] memory unvisited = new uint256[](_graph.vertexCount);
        uint256 unvisitedCount = 0;
        
        // 收集所有顶点并初始化距离
        for (uint256 v = 0; v < 1000; v++) { // 假设顶点ID小于1000
            if (_graph.vertices[v]) {
                distances[v] = v == source ? 0 : type(uint256).max;
                unvisited[unvisitedCount] = v;
                unvisitedCount++;
            }
        }
        
        while (unvisitedCount > 0) {
            // 找到距离最小的未访问顶点
            uint256 minDistance = type(uint256).max;
            uint256 currentVertex;
            uint256 currentIndex;
            
            for (uint256 i = 0; i < unvisitedCount; i++) {
                uint256 vertex = unvisited[i];
                if (distances[vertex] < minDistance) {
                    minDistance = distances[vertex];
                    currentVertex = vertex;
                    currentIndex = i;
                }
            }
            
            // 如果找不到可达顶点，退出
            if (minDistance == type(uint256).max) {
                break;
            }
            
            // 标记为已访问
            visited[currentVertex] = true;
            
            // 从未访问列表中移除
            unvisited[currentIndex] = unvisited[unvisitedCount - 1];
            unvisitedCount--;
            
            // 如果到达目标，可以提前退出
            if (currentVertex == destination) {
                break;
            }
            
            // 更新邻居距离
            uint256[] storage neighbors = _graph.adjacencyList[currentVertex];
            for (uint256 i = 0; i < neighbors.length; i++) {
                uint256 neighbor = neighbors[i];
                if (!visited[neighbor]) {
                    uint256 newDistance = distances[currentVertex] + 
                                        _graph.edges[currentVertex][neighbor].weight;
                    
                    if (newDistance < distances[neighbor]) {
                        distances[neighbor] = newDistance;
                        previous[neighbor] = currentVertex;
                    }
                }
            }
        }
        
        // 构建路径
        if (distances[destination] == type(uint256).max) {
            result.pathExists = false;
            result.distance = 0;
            result.path = new uint256[](0);
        } else {
            result.pathExists = true;
            result.distance = distances[destination];
            
            // 回溯路径
            uint256[] memory tempPath = new uint256[](1000);
            uint256 pathLength = 0;
            uint256 current = destination;
            
            while (current != source) {
                tempPath[pathLength] = current;
                pathLength++;
                current = previous[current];
            }
            tempPath[pathLength] = source;
            pathLength++;
            
            // 反转路径
            result.path = new uint256[](pathLength);
            for (uint256 i = 0; i < pathLength; i++) {
                result.path[i] = tempPath[pathLength - 1 - i];
            }
        }
        
        emit PathFound(
            source,
            destination,
            result.path,
            result.distance,
            "Dijkstra"
        );
    }
    
    /**
     * @dev 深度优先搜索 - O(V + E)
     * @param startVertex 起始顶点
     * @return visitOrder 访问顺序
     */
    function depthFirstSearch(uint256 startVertex)
        external
        returns (uint256[] memory visitOrder)
    {
        require(_graph.vertices[startVertex], "Start vertex does not exist");
        
        mapping(uint256 => bool) storage visited;
        uint256[] memory stack = new uint256[](1000);
        uint256[] memory result = new uint256[](1000);
        uint256 stackTop = 0;
        uint256 resultCount = 0;
        
        // 初始化栈
        stack[stackTop] = startVertex;
        stackTop++;
        
        while (stackTop > 0) {
            // 出栈
            stackTop--;
            uint256 current = stack[stackTop];
            
            if (!visited[current]) {
                visited[current] = true;
                result[resultCount] = current;
                resultCount++;
                
                // 将邻居入栈（逆序以保持正确的访问顺序）
                uint256[] storage neighbors = _graph.adjacencyList[current];
                for (int256 i = int256(neighbors.length) - 1; i >= 0; i--) {
                    uint256 neighbor = neighbors[uint256(i)];
                    if (!visited[neighbor]) {
                        stack[stackTop] = neighbor;
                        stackTop++;
                    }
                }
            }
        }
        
        // 复制结果到正确大小的数组
        visitOrder = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            visitOrder[i] = result[i];
        }
        
        emit GraphOperation(
            "DFS",
            startVertex,
            0,
            resultCount,
            "Depth First Search"
        );
    }
    
    /**
     * @dev 广度优先搜索 - O(V + E)
     * @param startVertex 起始顶点
     * @return visitOrder 访问顺序
     */
    function breadthFirstSearch(uint256 startVertex)
        external
        returns (uint256[] memory visitOrder)
    {
        require(_graph.vertices[startVertex], "Start vertex does not exist");
        
        mapping(uint256 => bool) storage visited;
        uint256[] memory queue = new uint256[](1000);
        uint256[] memory result = new uint256[](1000);
        uint256 queueFront = 0;
        uint256 queueRear = 0;
        uint256 resultCount = 0;
        
        // 初始化队列
        queue[queueRear] = startVertex;
        queueRear++;
        visited[startVertex] = true;
        
        while (queueFront < queueRear) {
            // 出队
            uint256 current = queue[queueFront];
            queueFront++;
            
            result[resultCount] = current;
            resultCount++;
            
            // 将未访问的邻居入队
            uint256[] storage neighbors = _graph.adjacencyList[current];
            for (uint256 i = 0; i < neighbors.length; i++) {
                uint256 neighbor = neighbors[i];
                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    queue[queueRear] = neighbor;
                    queueRear++;
                }
            }
        }
        
        // 复制结果到正确大小的数组
        visitOrder = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            visitOrder[i] = result[i];
        }
        
        emit GraphOperation(
            "BFS",
            startVertex,
            0,
            resultCount,
            "Breadth First Search"
        );
    }
    
    /**
     * @dev 检测环路（有向图）- O(V + E)
     * @return hasCycle 是否存在环路
     */
    function detectCycle() external returns (bool hasCycle) {
        require(_graph.isDirected, "Cycle detection implemented for directed graphs only");
        
        mapping(uint256 => uint8) storage color; // 0: 白色, 1: 灰色, 2: 黑色
        
        // 对所有顶点进行DFS
        for (uint256 v = 0; v < 1000; v++) {
            if (_graph.vertices[v] && color[v] == 0) {
                if (_dfsForCycle(v, color)) {
                    hasCycle = true;
                    break;
                }
            }
        }
        
        emit GraphOperation(
            "Cycle Detection",
            0,
            0,
            hasCycle ? 1 : 0,
            "DFS Cycle Detection"
        );
    }
    
    /**
     * @dev DFS环路检测辅助函数
     */
    function _dfsForCycle(
        uint256 vertex,
        mapping(uint256 => uint8) storage color
    ) internal returns (bool) {
        color[vertex] = 1; // 标记为灰色（正在访问）
        
        uint256[] storage neighbors = _graph.adjacencyList[vertex];
        for (uint256 i = 0; i < neighbors.length; i++) {
            uint256 neighbor = neighbors[i];
            
            if (color[neighbor] == 1) {
                // 发现后向边，存在环路
                return true;
            }
            
            if (color[neighbor] == 0 && _dfsForCycle(neighbor, color)) {
                return true;
            }
        }
        
        color[vertex] = 2; // 标记为黑色（访问完成）
        return false;
    }
    
    /**
     * @dev 获取图的统计信息
     * @return vertexCount 顶点数
     * @return edgeCount 边数
     * @return isDirected 是否为有向图
     */
    function getGraphStats()
        external
        view
        returns (
            uint256 vertexCount,
            uint256 edgeCount,
            bool isDirected
        )
    {
        return (_graph.vertexCount, _graph.edgeCount, _graph.isDirected);
    }
    
    // 个人心得：图算法是计算机科学的核心，在区块链中有广泛应用
    // 如网络拓扑分析、依赖关系管理、路由优化等
}
```

---

## 📚 学习心得与总结

### 🎯 核心收获

1. **数据结构选择的重要性**
   - 不同的数据结构适用于不同的场景
   - 在区块链环境中，存储成本是重要考量因素
   - 合理的数据结构设计可以显著降低Gas消耗

2. **算法复杂度优化策略**
   - 时间复杂度优化：缓存、动态规划、分治法
   - 空间复杂度优化：原地算法、位操作、数据压缩
   - 实际应用中需要在时间和空间之间找到平衡

3. **区块链特有的优化考虑**
   - Gas成本优化比传统的时间复杂度更重要
   - 批处理操作可以有效降低交易成本
   - 状态变量的读写成本差异巨大

4. **高级算法的实际应用**
   - 图算法在去中心化网络中的应用
   - 排序算法在数据处理中的选择策略
   - 搜索算法在大规模数据查询中的优化

### 🔍 深度思考

通过这段时间的学习，我深刻认识到算法和数据结构不仅仅是理论知识，更是解决实际问题的有力工具。在区块链开发中，每一行代码都可能影响到用户的使用成本，这让我更加重视代码的效率和优化。

特别是在实现复杂算法时，我学会了如何在保证功能正确性的前提下，通过巧妙的设计来降低计算复杂度和存储开销。这种思维方式不仅适用于智能合约开发，也为我今后的软件开发生涯奠定了坚实的基础。

### 🚀 未来学习方向

1. **高级数据结构研究**
   - 跳表、红黑树等平衡树结构
   - 布隆过滤器的变种和优化
   - 分布式数据结构设计

2. **算法优化深入**
   - 并行算法设计
   - 近似算法和启发式算法
   - 机器学习算法在区块链中的应用

3. **区块链特定优化**
   - Layer2解决方案的算法优化
   - 跨链通信的算法设计
   - 共识算法的性能优化

---

**学习感悟：** 算法和数据结构是程序员的内功，而在区块链这个新兴领域，传统的优化思路需要结合新的约束条件。每一次优化都是对问题本质的深入理解，每一个算法的实现都是对编程能力的提升。

**日期：** 2024年6月20日  
**签名：** 杨程喆 (2023111580)