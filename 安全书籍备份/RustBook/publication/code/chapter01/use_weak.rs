// use_weak.rs

use std::cell::RefCell;
use std::rc::{Rc, Weak};

struct Car {
    name: String,
    wheels: RefCell<Vec<Weak<Wheel>>>, // 引用 Wheel
}

struct Wheel {
    id: i32,
    car: Weak<Car>, // Weak 引用 Car
}

fn main() {
    let car: Rc<Car> = Rc::new(
        Car {
            name: "Tesla".to_string(),
            wheels: RefCell::new(vec![]),
        }
    );
    let wl1 = Rc::new(Wheel { id:1, car: Rc::downgrade(&car) });
    let wl2 = Rc::new(Wheel { id:2, car: Rc::downgrade(&car) });

    {
        let mut wheels = car.wheels.borrow_mut();
        // downgrade 得到 Weak
        wheels.push(Rc::downgrade(&wl1));
        wheels.push(Rc::downgrade(&wl2));
    } // 确保借用结束

    for wheel_weak in car.wheels.borrow().iter() {
        if let Some(wl) = wheel_weak.upgrade() {
            println!("wheel {} owned by {}", wl.id, wl.car.upgrade().unwrap().name);
        } else {
            println!("wheel weak reference has been dropped");
        }
    }
}
