//
//  ContentView.swift
//  NavigationBarScene
//
//  Created by lake on 2024/9/9.
//

import SwiftUI

struct RootView: View {
    struct Link2: View {
        var body: some View {
            Text("content")
                .onViewDidAppear { _ in
//                    print("come in")
                }
        }
    }

    struct Link1: View {
        @State var opacity: CGFloat?
        @State var fromAlpha: CGFloat = 0
        @State var toAlpha: CGFloat = 0
        @State var viewController: UIViewController? = nil
        @AppStorage("detail_opacity") var barOpacity: Double = 0.0

        var body: some View {
            ScrollView {
                VStack {
                    ForEach(0 ..< 20, id: \.self) { _ in
                        NavigationLink {
                            Link2()
                        } label: {
                            Text("link2")
                                .frame(height: 50)
                        }
                    }
                }
                .background(GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.frame(in: .global).minY) { v in
                        let progress = -v / 100
                        opacity = max(min(progress, 1), 0)
                        viewController?.toAlpha = opacity!
                    }
                })
            }
            .ignoresSafeArea(edges: .top)
            .onViewDidAppear { controller in
                viewController = controller
                controller.fromAlpha = fromAlpha
                controller.toAlpha = toAlpha
//                print("come in")
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
