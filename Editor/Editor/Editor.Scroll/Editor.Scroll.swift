//
//  Editor.Scroll.swift
//  Magma
//
//  Created by Maximilian Mackh on 24.02.23.
//

// Experimental replacement to TableView, haven't figured out how to adjust height dynamically, not usesd.

import UIKit
import BaseComponents

extension Editor {
    class Scroll: UIScrollView {
        private class Coordinate: Equatable, Hashable {
            var index: Int
            var y: CGFloat
            var height: CGFloat
            
            var visibleView: UIView? = nil
            
            init(index: Int, y: CGFloat, height: CGFloat) {
                self.index = index
                self.y = y
                self.height = height
            }
            
            static func ==(lhs: Coordinate, rhs: Coordinate) -> Bool {
                lhs.index == rhs.index
            }
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(index)
            }
        }
        
        var numberOfRows: Int = 0 
        var estimatedHeightPerRow: CGFloat = 44.0
        var customHeightHandler: ((_ index: Int)->(CGFloat?))?
        var additionalYOffset: CGFloat = 0
        
        private var coordinates: [Coordinate] = []
        private var visibleCoordinates: [Coordinate] = []
        private var customHeightStore: [Int:CGFloat] = [:]
        
        override var contentOffset: CGPoint {
            didSet {
                updateVisibleCells()
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            updateVisibleCells()
        }
        
        func reloadData() {
            
            calculateCoordinates()
        }
        
        func setHeight(for index: Int, height: CGFloat) {
            customHeightStore[index] = height
        }
        
        private func calculateCoordinates() {
            self.coordinates.removeAll()
            additionalYOffset = 0
            
            var yOffsetTracker: CGFloat = 0
            
            for i in 0..<numberOfRows {
                let height: CGFloat = estimatedHeightPerRow
                let y: CGFloat = yOffsetTracker
                yOffsetTracker += height
                self.coordinates.append(.init(index: i, y: y, height: height))
            }
            
            updateContentHeight(yOffsetTracker)
        }
        
        private func updateContentHeight(_ height: CGFloat) {
            contentSize = .init(width: bounds.width, height: height)
        }
        
        func updateVisibleCells() {
            if bounds == .zero { return }
            
            let minYOffset: CGFloat = contentOffset.y - safeAreaInsets.top - layoutMargins.top
            let maxYOffset: CGFloat = contentOffset.y + bounds.size.height
            
            var visible: [Coordinate] = []
            
            for coordinate in coordinates {
                let y: CGFloat = coordinate.y
                
                if (y >= minYOffset) && y <= maxYOffset {
                    visible.append(coordinate)
                }
            }
            
            if visible == visibleCoordinates { return }
            let previous: Set<Coordinate> = Set(visible)
            let current: Set<Coordinate> = Set(visibleCoordinates)
            visibleCoordinates = visible
            
            let added = previous.subtracting(current)
            let removed = current.subtracting(previous)
            
            for removedCoordinate in removed {
                removedCoordinate.visibleView?.removeFromSuperview()
            }
            
            for addedCoordinate in added.sorted(by: { $0.index < $1.index }) {
               
                
                let view: UIView = UIView()
                view.frame = .init(x: 0, y: addedCoordinate.y, width: bounds.width, height: addedCoordinate.height)
                view.backgroundColor = addedCoordinate.index % 2 == 0 ? .blue : .red
                addedCoordinate.visibleView = view
                addSubview(view)
            }
        }
    }
}
