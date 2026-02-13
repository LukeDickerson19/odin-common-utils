package main

// single line comment
/*
multi
line
comment
*/

import "core:fmt"

main :: proc() {
        fmt.println("Hello World!")
        variable_declaration()
        assignment_statement()
        basic_types()
        
}

variable_declaration :: proc() {
    // https://odin-lang.org/docs/overview/#variable-declarations

    x: int // declares `x` to have type `int`
    y, z: int // declares `y` and `z` to have type `int`
    // Variables are initialized to zero by default unless specified otherwise.
    // Note: Declarations have to be unique within a scope.
    x := 10
    // x := 20 // Redeclaration of `x` in this scope
    y, z := 20, 30
//     test, z := 20, 30 // not allowed since `z` exists already
}

assignment_statement :: proc() {
    // https://odin-lang.org/docs/overview/#assignment-statements

    x2: int = 123 // declares a new variable `x` with type `int` and assigns a value to it
    x2 = 637 // assigns a new value to `x`
    // = is the assignment operator.
    // You can assign multiple variables with it:
    x2, y := 1, "hello" // declares `x` and `y` and infers the types from the assignments
    y, x2 = "bye", 5
    // Note: := is two tokens, : and =. The following are all equivalent:
    x3: int = 123
    x3:     = 123 // default type for an integer literal is `int`
    x3 := 123
}

basic_types :: proc() {

    // source: https://odin-lang.org/docs/overview/#basic-types
    /*
    
    bool b8 b16 b32 b64 // booleans

    // integers
    int  i8 i16 i32 i64 i128
    uint u8 u16 u32 u64 u128 uintptr
    NOTE: u8 can also be char

    // endian specific integers
    i16le i32le i64le i128le u16le u32le u64le u128le // little endian
    i16be i32be i64be i128be u16be u32be u64be u128be // big endian

    f16 f32 f64 // floating point numbers

    // endian specific floating point numbers
    f16le f32le f64le // little endian
    f16be f32be f64be // big endian

    complex32 complex64 complex128 // complex numbers

    quaternion64 quaternion128 quaternion256 // quaternion numbers

    rune // signed 32 bit integer
        // represents a Unicode code point
        // is a distinct type to `i32`
    NOTE: with 32 bits a rune can represent any Unicode character, which includes non-english language characters, emojis, math symbols, music notation, currency symbols, etc.

    // strings
    string cstring

    // raw pointer type
    rawptr

    // runtime type information specific type
    typeid
    any

    The uintptr type is pointer sized, and the int, uint types are the “natural” register size, which is guaranteed to greater than or equal to the size of a pointer (i.e. size_of(uint) >= size_of(uintptr)). When you need an integer value, you should default to using int unless you have a specific reason to use a sized or unsigned integer type

    Note: The Odin string type stores the pointer to the data and the length of the string. cstring is used to interface with foreign libraries written in/for C that use zero-terminated strings.
    
     */
}