// Workspace.swift
import ProjectDescription

let workspace = Workspace(
  name: "StopLate",
  projects: [
    "Projects/App",   // 앱
    "Projects/**"     // Features/Clients/Shared/Extensions 전체
  ]
)
