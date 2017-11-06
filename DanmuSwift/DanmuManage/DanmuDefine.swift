//
//  DanmuDefine.swift
//  DanmuSwift
//
//  Created by 孙伟伟 on 2017/11/1.
//  Copyright © 2017年 孙伟伟. All rights reserved.
//

import Foundation
import UIKit

public let AppWidth: CGFloat = UIScreen.main.bounds.size.width
public let AppHeight: CGFloat = UIScreen.main.bounds.size.height

struct HJDanmakuTime {
   var time : CGFloat?;
   var interval : CGFloat?;
}

let CellHeight = 25;
let CellSpace = 5;
let Duration = 5.0;
let ljFrameInterval = 0.2;

class DanmuDefine: NSObject {
    public static let shared = DanmuDefine()
    func HJMaxTime(ljTime : HJDanmakuTime) -> CGFloat {
        return ljTime.time! + ljTime.interval!;
    }
    
    public func getTextCGSize(_ str : String, _ font : UIFont) -> CGSize {
        let size = str.size(withAttributes: [NSAttributedStringKey.font : font]);
        return size;
    }
}
