<?php

// Copyright (c) 2020, 2021 IBM Corporation, RedHat and others.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Script to get calculate the confidence interval of data

$datafile = $argv[1];
$data = file($datafile);
$conff_in = confidence_interval ( $data );
#echo "confidence interval is " . $conff_in;
echo round($conff_in,4) * 100;

function confidence_interval ( $scores ) {
        // First get the std deviation and other
        // useful values as floats.
        if (array_sum($scores) != 0) {
            $stddev = stddev( $scores );
            $count = floatval( count( $scores ) );
            $mean = floatval( array_sum( $scores ) ) / $count;
            // Do the convergence calculations.
            $ci = $stddev * t_dist05( count( $scores ) -1 );
            $ci /= $mean;
            $ci /= sqrt($count);
            return $ci;
        } else {
            return 0;
        }
}

function t_dist05( $N ) {

        // Constants for t-dist calculations.
        $Student_t_05 = array(
                -1.0,
                12.706, 4.303, 3.182, 2.776, 2.571,
                2.447, 2.365, 2.306, 2.262, 2.228,

                2.201, 2.179, 2.160, 2.145, 2.131,
                2.120, 2.110, 2.101, 2.093, 2.086,

                2.080, 2.074, 2.069, 2.064, 2.060,
                2.056, 2.052, 2.048, 2.045, 2.042
        );
        $Student_t_05_40    = 2.021;
        $Student_t_05_60    = 2.000;
        $Student_t_05_120   = 1.98;
        $Student_t_05_2000  = 1.96;

        $P = 0.0;

        if ($N <= 30) {
                $P = $Student_t_05[$N];
        } else if ($N <= 40) {
                $P = interp($Student_t_05[30], $Student_t_05_40, 30, 40, $N);
        } else if ($N <= 60) {
                $P = interp($Student_t_05_40 , $Student_t_05_60, 40, 60, $N);
        } else if ($N <= 120) {
                $P = interp($Student_t_05_60, $Student_t_05_120, 60, 120, $N);
        } else if ($N <= 2000) {
                $P = interp($Student_t_05_120, $Student_t_05_2000, 120, 2000, $N);
        } else {
                $P = $Student_t_05_2000;
        }
        return $P;
}

// Support function for t_dist05
function interp( $a, $b, $aN, $bN, $N ) {
        $mu = (floatval($N - $aN)) / floatval($bN - $aN);
        $v = $mu * ($b - $a) + $a;
        return $v;
}

function stddev( $scores ) {

        /* Make sure we are working with floating point
         * numbers.
         */
         //There is also a minor check here that makes sure that
         //we dont include NULL scores in the sd calculations.
         //We wont need this when the annotation tool is being used
         //as this should catch all 'bad' data.
         //This is only partially correct anyway because there are no checks
         //within the ci functions and so the data will still be wrong
         //and include NULL data.
        if ($scores !== NULL) {
            $bad_data = 0;
            if (in_array(NULL, $scores)) {
                foreach ($scores as $score) {
                    if ($score === NULL) {
                        $bad_data++;
                    }
                }
            }
            $count = floatval( count( $scores ) ) - $bad_data;
            if ($count == 0 || array_sum($scores) == 0)
                return NULL;
            $mean = floatval( array_sum( $scores ) ) / $count;
            $sum = 0.0;
            foreach ( $scores as $score ) {
                if ($score !== NULL) {
                    $score = floatval($score);
                    $difference = ($score - $mean);
                    $sum += $difference*$difference;
                }
            }

            if ($sum != 0 && $count != 0) {
                $stddev = sqrt( $sum / ($count - 1) );
                return $stddev;
            } else {
                return NULL;
            }
        } else {
            return NULL;
        }

}
?>
