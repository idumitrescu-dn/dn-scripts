#!/bin/bash

function py_pep8()
{
    type autopep8 > /dev/null 2>&1 || return
    git diff --name-only | grep ".py$" | xargs -r autopep8 -ri
}
