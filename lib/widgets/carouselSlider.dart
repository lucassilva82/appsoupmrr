import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

// ignore: must_be_immutable
class WidgetCarouselSlider extends StatefulWidget {
  int currentIndex = 0;
  WidgetCarouselSlider({Key? key}) : super(key: key);

  @override
  _WidgetCarouselSliderState createState() => _WidgetCarouselSliderState();
}

class _WidgetCarouselSliderState extends State<WidgetCarouselSlider> {
  var slides;
  _queryDb() {
    slides = FirebaseFirestore.instance
        .collection('stores')
        .snapshots()
        .map((list) => list.docs.map((doc) => doc.data()));
  }

  @override
  void initState() {
    _queryDb();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      height: MediaQuery.of(context).size.height * 0.28,
      child: StreamBuilder(
        stream: slides,
        builder: (context, AsyncSnapshot snap) {
          //if condition to get current state
          if (snap.hasError) {
            return Text(snap.error.toString());
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return LinearProgressIndicator();
          }

          List slideList = snap.data.toList();

          return _carouselSlider(slideList);
        },
      ),
    );
  }

  _carouselSlider(List slideList) {
    CarouselController _controller = CarouselController();

    final List<Widget> imageSliders = slideList
        .map((item) => InkWell(
              child: Container(
                child: Container(
                  margin: EdgeInsets.all(8.0),
                  child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(5.0)),
                      child: Stack(
                        children: <Widget>[
                          Image.network(
                            item['img'],
                            fit: BoxFit.fill,
                            width: 300,
                            height: 200,
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              return child;
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              } else {
                                return const SizedBox(
                                    child: Center(
                                        child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                )));
                              }
                            },
                          ),
                          Positioned(
                            bottom: 0.0,
                            left: 0.0,
                            right: 0.0,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(200, 0, 0, 0),
                                    Color.fromARGB(0, 0, 0, 0)
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 20.0),
                              child: const Text(
                                '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
                ),
              ),
            ))
        .toList();

    return Container(
      child: Column(
        children: [
          Container(
            child: CarouselSlider(
              carouselController: _controller,
              options: CarouselOptions(
                height: MediaQuery.of(context).size.height * 0.24,
                aspectRatio: 2.0,
                enlargeCenterPage: true,
                scrollDirection: Axis.horizontal,
                autoPlay: true,
                onPageChanged: (index, reason) {
                  widget.currentIndex = index;
                  setState(() {});
                },
              ),
              items: imageSliders,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < imageSliders.length; i++)
                Container(
                  height: 13,
                  width: 13,
                  margin: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color:
                          widget.currentIndex == i ? Colors.blue : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey,
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: Offset(2, 2))
                      ]),
                )
            ],
          )
        ],
      ),
    );
  }
}
