void test_points_base_cap () {
    int score = Objects.Item.calculate_points_score (180, 0, 10, false, 1);
    assert (score == 24);
}

void test_points_early_bonus () {
    int score = Objects.Item.calculate_points_score (30, -5, 10, false, 1);
    assert (score == 7);
}

void test_points_late_after_grace_half () {
    int score = Objects.Item.calculate_points_score (30, 15, 10, false, 1);
    assert (score == 3);
}

void test_points_assume_working_full () {
    int score = Objects.Item.calculate_points_score (30, 15, 10, true, 1);
    assert (score == 6);
}

void test_points_relaxed_curve_thresholds () {
    int score_15 = Objects.Item.calculate_points_score (30, 25, 10, false, 0);
    assert (score_15 == 4);

    int score_45 = Objects.Item.calculate_points_score (30, 55, 10, false, 0);
    assert (score_45 == 3);

    int score_over_45 = Objects.Item.calculate_points_score (30, 56, 10, false, 0);
    assert (score_over_45 == 1);
}

void test_points_strict_curve_thresholds () {
    int score_5 = Objects.Item.calculate_points_score (30, 15, 10, false, 2);
    assert (score_5 == 3);

    int score_15 = Objects.Item.calculate_points_score (30, 25, 10, false, 2);
    assert (score_15 == 1);

    int score_over_15 = Objects.Item.calculate_points_score (30, 26, 10, false, 2);
    assert (score_over_15 == 0);
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/points/base_cap", test_points_base_cap);
    Test.add_func ("/points/early_bonus", test_points_early_bonus);
    Test.add_func ("/points/late_after_grace_half", test_points_late_after_grace_half);
    Test.add_func ("/points/assume_working_full", test_points_assume_working_full);
    Test.add_func ("/points/relaxed_curve_thresholds", test_points_relaxed_curve_thresholds);
    Test.add_func ("/points/strict_curve_thresholds", test_points_strict_curve_thresholds);

    Test.run ();
}
