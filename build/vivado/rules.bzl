"""Vivado rules for Bazel."""

load("//internal:vivado_project.bzl", _vivado_project = "vivado_project")
load("//internal:vivado_synthesis.bzl", _vivado_synthesis = "vivado_synthesis")
load("//internal:vivado_synthesis2.bzl", _vivado_synthesis2 = "vivado_synthesis2")
load("//internal:vivado_place_and_route.bzl", _vivado_place_and_route = "vivado_place_and_route")
load("//internal:vivado_place_and_route2.bzl", _vivado_place_and_route2 = "vivado_place_and_route2")
load("//internal:vivado_program_device.bzl", _vivado_program_device = "vivado_program_device")
load("//internal:vivado_library.bzl", _vivado_library = "vivado_library")
load("//internal:vivado_simulation.bzl", _vivado_simulation = "vivado_simulation")
load("//internal:vivado_unisims_library.bzl", _vivado_unisims_library = "vivado_unisims_library")
load("//internal:vivado_generics.bzl", _vivado_generics = "vivado_generics")
load("//internal:vivado_repl.bzl", _vivado_repl = "vivado_repl")

vivado_project = _vivado_project
vivado_synthesis = _vivado_synthesis
vivado_synthesis2 = _vivado_synthesis2
vivado_place_and_route = _vivado_place_and_route
vivado_place_and_route2 = _vivado_place_and_route2
vivado_program_device = _vivado_program_device
vivado_library = _vivado_library
vivado_simulation = _vivado_simulation
vivado_unisims_library = _vivado_unisims_library
vivado_generics = _vivado_generics
vivado_repl = _vivado_repl
