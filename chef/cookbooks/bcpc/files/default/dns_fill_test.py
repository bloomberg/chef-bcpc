#!/usr/bin/env python

from dns_fill import make_rfc1123_compliant
import unittest


class TestMakeRFC112Compliant(unittest.TestCase):
    def test_already_good_hostname(self):
        name = 'testname'
        result = name
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_spaces(self):
        name = 'this is a hostname'
        result = 'this-is-a-hostname'
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_uppercase(self):
        name = 'This Is A Hostname'
        result = 'this-is-a-hostname'
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_begin_hyphen(self):
        name = '-hello'
        result = 'hyphen-hello'
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_final_hyphen(self):
        name = 'hello-'
        result = 'hello-hyphen'
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_lots_of_bad_characters(self):
        name = 'this&isdjs^js)(8jFnjdal482S29!@#$!#@$(%*$*##('
        result = 'this-and-isdjs-js-8jfnjdal482s29-hyphen'
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_truncation(self):
        name = ('this is an extremely extremely extremely extremely extremely '
                'extremely extremely extremely extremely extremely extremely '
                'long hostname')
        result = ('this-is-an-extremely-extremely-extremely-extremely-'
                  'extremely-ex')
        self.assertEqual(
            make_rfc1123_compliant(name),
            result)

    def test_final_hyphen_as_63rd_character(self):
        name = ('this is a very long hostname that ends in a hyphen '
                'liiike this-')
        result = ('this-is-a-very-long-hostname-that-ends-in-a-hyphen-'
                  'liiik-hyphen')
        self.assertEqual(
             make_rfc1123_compliant(name),
             result)

if __name__ == '__main__':
    unittest.main()
