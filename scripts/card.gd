extends Control

var value := ""

func set_value(v):
    value = str(v)
    $Label.text = value
