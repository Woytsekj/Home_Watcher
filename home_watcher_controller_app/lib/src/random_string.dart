// Copyright (c) 2016, Damon Douglas. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Simple library for generating random ascii strings.
///
/// More dartdocs go here.
///
///
/// A simple usage example:
///
/// import 'package:random_string/random_string.dart' as random;
/// main() {
///     print(randomBetween(10,20)); // some integer between 10 and 20
///     print(randomNumeric(4)); // sequence of 4 random numbers i.e. 3259
///     print(randomString(10)); // random sequence of 10 characters i.e. e~f93(4l-
///     print(randomAlpha(5)); // random sequence of 5 alpha characters i.e. aRztC
///     print(randomAlphaNumeric(10)); // random sequence of 10 alpha numeric i.e. aRztC1y32B
/// }
library;


import 'dart:math';

const asciiStart = 33;
const asciiEnd = 126;
const numericStart = 48;
const numbericEnd = 57;

/// Generates a random integer where [from] <= [to].
int randomBetween(int from, int to) {
  if (from > to) throw Exception('$from cannot be > $to');
  var rand = Random();
  return ((to - from) * rand.nextDouble()).toInt() + from;
}

/// Generates a random string of [length] with characters
/// between ascii [from] to [to].
/// Defaults to characters of ascii '!' to '~'.
String randomString(int length, {int from = asciiStart, int to = asciiEnd}) {
  return String.fromCharCodes(
      List.generate(length, (index) => randomBetween(from, to)));
}

/// Generates a random string of [length] with only numeric characters.
String randomNumeric(int length) =>
    randomString(length, from: numericStart, to: numbericEnd);