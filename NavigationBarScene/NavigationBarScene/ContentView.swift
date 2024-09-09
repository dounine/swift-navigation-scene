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
                .onViewDidAppear { controller in
//                    print("come in")
                }
        }
    }

    struct Link1: View {
        var body: some View {
            List {
                ForEach(0 ..< 20, id: \.self) { _ in
                    NavigationLink {
                        Link2()
                    } label: {
                        Text("link2")
                    }
                    .frame(height: 50)
                }
            }
            .onViewDidAppear { controller in
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
