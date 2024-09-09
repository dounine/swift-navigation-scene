//
//  ContentView.swift
//  NavigationBarScene
//
//  Created by lake on 2024/9/9.
//

import SwiftUI

struct RootView: View {
    struct Link2: View {
        @State var viewController: UIViewController? = nil
        var body: some View {
            ScrollView {
                ForEach(0 ..< 20, id: \.self) { _ in
                    Text("content")
                        .frame(height: 50)
                }
            }
            .onViewDidAppear {
                viewController = $0
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        print("come in", viewController?.alpha)
                    } label: {
                        Text("alpha值")
                    }
                }
            }
        }
    }

    struct Link1: View {
//        @State var opacity: CGFloat?
        @State var fromAlpha: CGFloat = 0
        @State var toAlpha: CGFloat = 0
        @State var viewController: UIViewController? = nil
        @AppStorage("detail_opacity") var barOpacity: Double = 0.0
        @State var back = false

        var body: some View {
            ScrollView {
                VStack {
                    ForEach(0 ..< 20, id: \.self) { _ in
                        NavigationLink {
                            Link2()
                                .onAppear {
                                    back = true
                                    viewController?.alphaToggle()
                                    viewController?.alpha = 1.0
                                }
                        } label: {
                            Text("link2")
                                .frame(height: 50)
                        }
                    }
                }
                .background(GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.frame(in: .global).minY) { v in
                        let progress = -v / 100
                        barOpacity = max(min(progress, 1), 0)
                        viewController?.fromAlpha = barOpacity
                        viewController?.alpha = barOpacity
                    }
                })
            }
            .ignoresSafeArea(edges: .top)
            .onViewDidAppear { controller in
                print("onViewDidAppear barOpacity:\(barOpacity)")
                viewController = controller
                if back {
                    viewController?.fromAlpha = barOpacity
                } else {
                    viewController?.toAlpha = 0
                }
                viewController?.alpha = barOpacity
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    Link1()
                } label: {
                    Text("link1")
                }
            }
            .navigationTitle("大标题")
        }
    }
}

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}
